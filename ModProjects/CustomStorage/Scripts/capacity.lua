local M={}
local function valid(v)
    local ok,result=pcall(function()return v and v:IsValid()end)
    return ok and result
end
function M.create(settings,config,classes,record,log)
    local applied={}
    local function identify(inv)
        if not valid(inv) or inv:GetFullName():find('Default__',1,true) then return end
        local owner=inv:GetOwner()
        if not valid(owner) or owner:GetFullName():find('Default__',1,true) or not owner:HasAuthority() then return end
        local cls=owner:GetClass()
        local className=cls:GetFullName():match('^[^ ]+ (.*)$')
        local name=classes[className]
        if owner:IsA('/Script/Vein.VeinPlayerCharacter') then
            if not owner:IsLocallyControlled() or not valid(owner.Inventory) or owner.Inventory:GetFullName()~=inv:GetFullName() then return end
            name='Player'
        end
        if name and settings[name] then return name,owner end
    end
    local function snapshot(entry)
        local inv=entry.object
        local owner=inv:GetOwner()
        return {entry=entry,raw=inv.MaxWeight,owner=owner,playerBase=entry.name=='Player' and owner.MaxBaseCarryWeight,playerCap=entry.name=='Player' and owner.MaxCapCarryWeight}
    end
    local function restore(saved)
        if not valid(saved.entry.object) then return end
        if saved.entry.name=='Player' then
            if valid(saved.owner) then saved.owner.MaxBaseCarryWeight=saved.playerBase;saved.owner.MaxCapCarryWeight=saved.playerCap end
        else saved.entry.object:SetMaxWeight(saved.raw) end
    end
    local function set(entry,input)
        local inv=entry.object;local owner=inv:GetOwner()
        local base=entry.base
        if entry.name=='Player' then
            base=entry.playerBase+(inv:GetMaxWeight()-owner.MaxBaseCarryWeight)
        end
        local target=config.target(input[entry.name].Weight,base)
        if entry.name=='Player' then
            if target then
                local bonus=inv:GetMaxWeight()-owner.MaxBaseCarryWeight
                owner.MaxBaseCarryWeight=target-bonus;owner.MaxCapCarryWeight=target
            else owner.MaxBaseCarryWeight=entry.playerBase;owner.MaxCapCarryWeight=entry.playerCap end
        else inv:SetMaxWeight(target and target/0.453592 or entry.raw) end
        if target then
            local effective=inv:GetMaxWeight()
            assert(math.abs(effective-target)<math.max(0.0001,target*0.000001),'Effective weight did not change for '..entry.name..'; observed '..tostring(effective))
        end
        return target or base
    end
    local function apply(inv)
        local name,owner=identify(inv)
        if not name then return false end
        local key=inv:GetFullName()
        if applied[key] and valid(applied[key].object) then return true end
        local base=inv:GetMaxWeight()
        assert(type(base)=='number' and base>0 and base<math.huge,'Invalid base weight for '..name)
        local entry={object=inv,name=name,base=base,raw=inv.MaxWeight,playerBase=name=='Player' and owner.MaxBaseCarryWeight,playerCap=name=='Player' and owner.MaxCapCarryWeight}
        local saved=snapshot(entry)
        local ok,target=pcall(set,entry,settings)
        if not ok then restore(saved);error(target) end
        applied[key]=entry
        record(name,base)
        log(name..': base='..tostring(base)..'; limit='..tostring(target))
        return true
    end
    local function update(input)
        for _,name in ipairs(config.names) do assert(input[name],'Missing section '..name);config.validate(input[name].Weight) end
        local old=settings;local saved={};local count=0
        local function undo()
            settings=old
            for i=#saved,1,-1 do restore(saved[i]) end
        end
        local ok,err=pcall(function()
            for key,entry in pairs(applied) do
                if not valid(entry.object) then applied[key]=nil
                elseif identify(entry.object) then
                    saved[#saved+1]=snapshot(entry)
                    set(entry,input);count=count+1
                end
            end
        end)
        if not ok then undo();error(err) end
        settings=input
        return undo,'Saved and applied to '..count..' loaded inventories. New inventories use these settings.'
    end
    return {identify=identify,apply=apply,update=update}
end
return M
