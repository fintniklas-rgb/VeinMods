-- Crafting-click integration: native item staging with remainder restoration.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('/','\\')
local scripts=assert(source:match('^(.*)\\[^\\]+$'))
local folder=scripts:match('^(.*)\\Scripts$')
local verbose=false
local function log(message)
    if not verbose and not message:find('ERROR',1,true) and not message:find('ABORTED',1,true) and not message:find('ready',1,true) and not message:find('passed',1,true) and not message:find('integration;',1,true) and not message:find('Live config',1,true) then return end
    print('[CraftFromContainer] '..message..'\n')
    local f=io.open(folder..'\\api-discovery.log','ab')
    if f then f:write(message..'\n');f:close() end
end
local config=io.open(folder..'\\config.ini','rb')
local contents=config and config:read('*a') or '';if config then config:close() end
verbose=contents:match('VerboseLogging%s*=%s*true')~=nil
local radius=tonumber(contents:match('RadiusMetres%s*=%s*([%d%.]+)')) or 100
assert(radius>=1 and radius<=1000,'RadiusMetres must be between 1 and 1000')
log('Crafting integration; storage radius '..radius..' metres.')
local network=dofile(scripts..'\\network.lua')
local storage=dofile(scripts..'\\storage.lua')
local crafting=dofile(scripts..'\\crafting.lua')
assert(network.self_test())
assert(dofile(scripts..'\\tests.lua')(crafting))
assert(dofile(scripts..'\\availability-tests.lua')(dofile(scripts..'\\availability.lua'),network,crafting))
log('Planning and crafting transaction mock tests passed.')
local pending=false;local installed=false;local transactions={};local nativeAttempts={}
local function pre(context,benchParam,recipeParam,quantityParam)
    local component=context:get();local key=component:GetFullName()
    if transactions[key] then log('Nested crafting request ignored.');return end
    local actor=component:GetOwner()
    if not actor or not actor:IsValid() or not actor:HasAuthority() or not actor:IsLocallyControlled() then return end
    local bench=benchParam:get();local recipe=recipeParam:get();local quantity=quantityParam:get()
    if not bench or not bench:IsValid() or not recipe or not recipe:IsValid() or quantity<1 then return end
    nativeAttempts[recipe:GetFullName()]=os.clock()
    log('Crafting click received: '..recipe:GetRecipeName():ToString()..'; quantity='..quantity)
    local ok,message=pcall(function()
        local craft=bench
        log('Crafting station component: '..bench:GetFullName())
        local station=bench:GetOwner()
        assert(station and station:IsValid(),'Crafting station owner is unavailable')
        local stores=storage.discover(actor,station:K2_GetActorLocation(),radius,network)
        log('Eligible storage at crafting station='..#stores)
        transactions[key]=crafting.stage(actor,craft,recipe,quantity,stores,log)
        if transactions[key] then transactions[key].craft=craft end
        if verbose and transactions[key] then
            local transaction=transactions[key]
            transaction.craft=craft
            local success,problem=pcall(function()
                transaction.queueBefore=craft.Queue:GetArrayNum()
                local outIndex={}
                local allowed=recipe:CanBeCrafted(actor,craft,quantity,outIndex)
                log('Native recipe eligibility after staging='..tostring(allowed)..'; set='..tostring(outIndex.OutSetIndex)..'; queue before='..transaction.queueBefore)
                for index=0,recipe.PossibleIngredients:GetArrayNum()-1 do
                    local set=recipe:GetIngredientsForSet(actor,index)
                    for _,requirement in ipairs(crafting.values(set.Ingredients))do
                        local total=0
                        for _,item in ipairs(crafting.values(transaction.player:GetItemsOfClass(requirement.Item,false,true)))do total=total+item.Stack end
                        log('Native workbench class total='..total..'; required='..requirement.Quantity*quantity..'; set='..index)
                    end
                end
            end)
            if not success then log('ELIGIBILITY DIAGNOSTIC ERROR '..tostring(problem)) end
        end
    end)
    if not ok then log('CRAFT PRE ERROR '..tostring(message)) end
end
local function post(context)
    local key=context:get():GetFullName();local transaction=transactions[key]
    transactions[key]=nil
    if transaction then
        if verbose then
            local ok,message=pcall(function()log('Native queue after request='..transaction.craft.Queue:GetArrayNum()) end)
            if not ok then log('QUEUE DIAGNOSTIC ERROR '..tostring(message)) end
            crafting.observe(transaction,log)
        end
        if crafting.restore(transaction,log) then log('Native crafting returned; remaining staged materials restored.')
        else log('Native crafting returned; some staged materials remain in the workbench. See RESTORE ERROR.') end
    end
end
local live=dofile(scripts..'\\live-config.lua');assert(live.self_test())
local bridge=live.start('CraftFromContainer',folder..'\\config.ini',function(updated)
    local oldRadius,oldVerbose=radius,verbose
    local newRadius=live.number(assert(live.get(updated,'Storage','RadiusMetres')),1,1000)
    local newVerbose=live.get(updated,'Diagnostics','VerboseLogging')
    assert(newVerbose=='true' or newVerbose=='false','VerboseLogging must be true or false')
    radius=newRadius;verbose=newVerbose=='true'
    return function()radius=oldRadius;verbose=oldVerbose end,'Saved. The next crafting click uses '..radius..' metres.'
end,log)
LoopAsync(1000,function()
    if installed and not bridge.pending() then return false end
    if pending then return false end
    pending=true
    ExecuteInGameThread(function()
        local ok,message=pcall(function()
            bridge.poll()
            if installed then return end
            local transferType=StaticFindObject('/Script/Vein.VeinPlayerCharacter:Server_TransferOneStack')
            transferType:ForEachProperty(function(field)
                if field:GetFName():ToString()=='Item' then
                    local structName=field:GetStruct():GetFullName()
                    log('Single-stack native parameter type: '..structName)
                    assert(structName=='ScriptStruct /Script/Vein.VirtualItemInstance','Transfer item schema differs; refusing inventory changes')
                end
            end)
            RegisterHook('/Script/Vein.WorkbenchInteractionComponent:Server_QueueRecipe',pre,post)
            dofile(scripts..'\\availability.lua')(network,storage,crafting,radius,log,function(actor,bench,recipe)
                local previous=nativeAttempts[recipe:GetFullName()]
                if previous and os.clock()-previous<0.5 then return end
                assert(actor and actor:IsValid() and actor:HasAuthority() and actor:IsLocallyControlled(),'Local crafting authority unavailable')
                local interaction=actor.WorkbenchInteractionComponent
                assert(interaction and interaction:IsValid(),'Workbench interaction component unavailable')
                log('Recipe click bridge requesting native craft: '..recipe:GetRecipeName():ToString())
                nativeAttempts[recipe:GetFullName()]=os.clock()
                interaction:Server_QueueRecipe(bench,recipe,1)
            end)
            installed=true;log('Crafting click hook ready. Singleplayer native material staging enabled.')
        end)
        pending=false;if not ok then log('HOOK ERROR '..tostring(message));installed=true end
    end)
    return false
end)

