-- Stage remote materials using native transfer, let native crafting consume them,
-- then return every surviving staged stack. Never create or manually delete items.
local M={}
local function valid(v)return v and v:IsValid() end
local function unwrap(value)
    for _=1,3 do
        if type(value)~='table' and type(value)~='userdata' then break end
        local ok,getter=pcall(function()return value.get end)
        if not ok or type(getter)~='function' then break end
        local nextValue=getter(value)
        if nextValue==value then break end
        value=nextValue
    end
    return value
end
local function values(array)
    array=unwrap(array)
    if type(array)=='table' and type(array.ForEach)~='function' then
        local result={};local keys={}
        for key in pairs(array)do if type(key)=='number' then keys[#keys+1]=key end end
        table.sort(keys);for _,key in ipairs(keys)do result[#result+1]=unwrap(array[key]) end
        return result
    end
    local result={};array:ForEach(function(_,value)result[#result+1]=unwrap(value) end);return result
end
M.values=values
local function findItem(inventory,id)
    -- Keep a native struct wrapper: function-return tables omit unsupported
    -- SoftClassProperty/InstancedStruct fields, making transferred items invalid.
    -- The reflected inventory array preserves the complete native item value.
    for _,item in ipairs(values(inventory.Items.Items))do
        if item.ID.Data==id.Data then return item end
    end
end
function M.cached_matches()
    local cache={}
    return function(inventory,requirement)
        local value=requirement.kind=='item' and requirement.value.Item or requirement.value.Tag
        local ok,name=pcall(function()return value:GetFullName()end)
        if not ok then ok,name=pcall(function()return value:ToString()end) end
        if not ok then name=tostring(value) end
        local key=inventory:GetFullName()..'|'..requirement.kind..'|'..name
        if cache[key]==nil then
            local array
            if requirement.kind=='item' then array=inventory:GetItemsOfClass(value,false,true)
            else array=inventory:GetItemsOfTag(value,true) end
            cache[key]=values(array)
        end
        return cache[key]
    end
end
function M.plan(actor,craft,recipe,quantity,stores,lookup)
    local player=craft:GetInventory()
    assert(valid(player),'Workbench inventory unavailable')
    local inventories={player};for _,inventory in ipairs(stores)do inventories[#inventories+1]=inventory end
    for index=0,recipe.PossibleIngredients:GetArrayNum()-1 do
        local set=recipe:GetIngredientsForSet(actor,index)
        if set.bEnabled then
            local plan={};local reserved={};local complete=true
            local function match(inventory,requirement)
                if lookup then return lookup(inventory,requirement) end
                if requirement.kind=='item' then return inventory:GetItemsOfClass(requirement.value.Item,false,true) end
                return inventory:GetItemsOfTag(requirement.value.Tag,true)
            end
            local requirements={}
            for _,item in ipairs(values(set.Ingredients))do requirements[#requirements+1]={kind='item',value=item} end
            for _,tag in ipairs(values(set.IngredientTags))do requirements[#requirements+1]={kind='tag',value=tag} end
            for _,requirement in ipairs(requirements)do
                local remaining=requirement.value.Quantity*quantity
                for n,inventory in ipairs(inventories)do
                    if remaining<=0 then break end
                    local array=match(inventory,requirement)
                    local matches=values(array)
                    for _,item in ipairs(matches)do
                        if remaining<=0 then break end
                        local id=item.ID.Data
                        local amount=math.min(remaining,math.max(0,item.Stack-(reserved[id] or 0)))
                        if amount>0 then
                            reserved[id]=(reserved[id] or 0)+amount;remaining=remaining-amount
                            if n>1 then
                                if not plan[id] then plan[id]={source=inventory,id={Data=id},amount=item.Stack,needed=0} end
                                plan[id].needed=plan[id].needed+amount
                            end
                        end
                    end
                end
                if remaining>0 then complete=false;break end
            end
            if complete then return plan,player end
        end
    end
end
local function snapshot(inventory)
    local result={}
    for _,item in ipairs(values(inventory.Items.Items))do result[item.ID.Data]=item.Stack end
    return result
end
local function transfer(source,destination,item,actor)
    assert(item.Inventory and item.Inventory:IsValid() and item.Inventory:GetFullName()==source:GetFullName(),'Native item source changed')
    -- A flat native struct parameter avoids the nested transfer request bridge.
    -- The runtime's complete struct copy was verified with live item validation.
    local id=item.ID.Data;local count=item.Stack
    local before=snapshot(destination)
    actor:Server_TransferOneStack(item,destination)
    local remaining=findItem(source,{Data=id})
    local removed=count-(remaining and remaining.Stack or 0)
    local received={};local added=0
    for _,current in ipairs(values(destination.Items.Items))do
        local delta=current.Stack-(before[current.ID.Data] or 0)
        if delta>0 then received[#received+1]={id={Data=current.ID.Data},units=delta};added=added+delta end
    end
    return received,removed,added
end
function M.restore(transaction,log)
    local restored=0;local allReturned=true
    for _,entry in ipairs(transaction.moved)do
        local ok,message=pcall(function()
            for _=1,entry.units do
                local remaining=findItem(transaction.player,entry.id)
                local baseline=transaction.baseline[entry.id.Data] or 0
                if not remaining or remaining.Stack<=baseline then break end
                local _,removed,added=transfer(transaction.player,entry.source,remaining,transaction.actor)
                log('Return unit result: workbench removed='..removed..'; storage added='..added..'; workbench ID='..tostring(entry.id.Data))
                assert(removed==1 and added==1,'Surviving material unit could not be returned')
                restored=restored+1
            end
        end)
        if not ok then allReturned=false;log('RESTORE ERROR '..tostring(message)..'; item ID='..entry.id.Data) end
    end
    log('Staged material units returned='..restored)
    return allReturned
end
function M.stage(actor,craft,recipe,quantity,stores,log)
    local plan,player=M.plan(actor,craft,recipe,quantity,stores)
    if not plan then log('No complete material plan; native crafting remains unchanged.');return nil end
    local transaction={actor=actor,player=player,moved={},baseline=snapshot(player)}
    local entries={};for _,entry in pairs(plan)do entries[#entries+1]=entry end
    table.sort(entries,function(a,b)return tostring(a.id.Data)<tostring(b.id.Data)end)
    local total=0
    local ok,message=pcall(function()
        for _,entry in ipairs(entries)do
            -- Revalidate immediately before transfer; no cached world inventory edits.
            assert(not entry.source:HasLock(),'Storage became locked')
            local live=findItem(entry.source,entry.id)
            assert(live and live.Stack==entry.amount,'Storage contents changed')
            assert(entry.needed>=1 and entry.needed%1==0,'Material quantity must be a positive integer')
            log('Staging required units='..entry.needed..'; source ID='..tostring(entry.id.Data))
            for _=1,entry.needed do
                assert(not entry.source:HasLock(),'Storage became locked')
                live=findItem(entry.source,entry.id)
                assert(live and live.Stack>0,'Source material disappeared')
                local received,removed,added=transfer(entry.source,player,live,actor)
                -- Record actual destination IDs before validating the result,
                -- so a later rejection can return units already moved.
                for _,part in ipairs(received)do
                    transaction.moved[#transaction.moved+1]={source=entry.source,id=part.id,units=part.units}
                    local current=findItem(player,part.id)
                    log('Staged destination ID='..tostring(part.id.Data)..'; added='..part.units..'; current stack='..tostring(current and current.Stack or 0))
                end
                assert(removed==1 and added==1,'Native single-unit transfer was rejected or changed quantity')
                total=total+1
            end
        end
    end)
    if not ok then M.restore(transaction,log);log('STAGING ABORTED '..tostring(message));return nil end
    log('Crafting materials staged; remote units='..total..'; source stacks='..#entries)
    return transaction
end
function M.observe(transaction,log)
    local seen={}
    for _,entry in ipairs(transaction.moved)do
        if not seen[entry.id.Data] then
            seen[entry.id.Data]=true
            local current=findItem(transaction.player,entry.id)
            log('Workbench material observation: ID='..tostring(entry.id.Data)..'; stack='..tostring(current and current.Stack or 0))
        end
    end
end
return M

