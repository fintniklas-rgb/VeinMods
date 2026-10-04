return function(config,capacity,classes)
    local records={};local messages={}
    local settings={}
    for _,name in ipairs(config.names) do settings[name]={Weight='default'} end
    local function object(name)
        return {IsValid=function()return true end,GetFullName=function()return name end}
    end
    local serial=0
    local function inventory(path,raw,player)
        serial=serial+1
        local owner=object('Actor /World.Test')
        owner.HasAuthority=function()return true end
        owner.GetClass=function()return object('BlueprintGeneratedClass '..path)end
        owner.IsA=function()return player or false end
        owner.IsLocallyControlled=function()return true end
        owner.MaxBaseCarryWeight=45;owner.MaxCapCarryWeight=181
        local inv=object('InventoryComponent /World.Test'..serial..'.Inventory')
        inv.GetOwner=function()return owner end
        inv.MaxWeight=raw
        inv.SetMaxWeight=function(self,value)self.MaxWeight=value end
        inv.GetMaxWeight=function(self)
            if player then return math.min(owner.MaxBaseCarryWeight+55,owner.MaxCapCarryWeight) end
            return self.MaxWeight*0.453592
        end
        owner.Inventory=inv
        return inv,owner
    end
    local function controller()
        return capacity.create(settings,config,classes,function(name,base)records[name]=base end,function(message)messages[#messages+1]=message end)
    end
    for path,name in pairs(classes) do
        settings[name].Weight='3x'
        local inv=inventory(path,100)
        assert(controller().apply(inv))
        assert(math.abs(inv:GetMaxWeight()-136.0776)<0.0001,'Multiplier/conversion failed: '..name)
        assert(math.abs(records[name]-45.3592)<0.0001)
        settings[name].Weight='1'
        inv=inventory(path,100)
        assert(controller().apply(inv) and math.abs(inv:GetMaxWeight()-1)<0.0001,'Minimum failed: '..name)
        settings[name].Weight='default'
    end
    local foreign=inventory('/Game/Vein/Containers/Industrial/BP_Crate02.BP_Crate02_C',100)
    assert(not controller().apply(foreign) and foreign.MaxWeight==100,'Unlisted loot crate was modified')
    settings.Player.Weight='3x'
    local inv,owner=inventory('/Game/Player.Player_C',136.078,true)
    assert(controller().apply(inv) and inv:GetMaxWeight()==300 and records.Player==100)
    -- Actual observed VEIN calculation: base field + 112.944408 kg.
    -- MaxCapCarryWeight does not clamp this getter to the requested value.
    for _,weight in ipairs({1,3,300,600}) do
        settings.Player.Weight=tostring(weight)
        local actual,aOwner=inventory('/Game/Player.Player_C',136.078,true)
        aOwner.MaxBaseCarryWeight=45.359199523926
        actual.GetMaxWeight=function()return aOwner.MaxBaseCarryWeight+112.944408 end
        assert(controller().apply(actual))
        assert(math.abs(actual:GetMaxWeight()-weight)<0.0001,'Player additive capacity regression')
    end
    settings.Player.Weight='3x'
    local other=inventory('/Game/Player.Player_C',136.078,true)
    other:GetOwner().IsLocallyControlled=function()return false end
    assert(not controller().apply(other),'Remote player was modified')
    local broken,bOwner=inventory('/Game/Player.Player_C',136.078,true)
    broken.GetMaxWeight=function()return 100 end
    assert(not pcall(controller().apply,broken))
    assert(bOwner.MaxBaseCarryWeight==45 and bOwner.MaxCapCarryWeight==181,'Failed player change was not restored')
    settings.Player.Weight='300'
    local livePlayer,lOwner=inventory('/Game/Player.Player_C',136.078,true)
    lOwner.MaxBaseCarryWeight=45.359199523926
    livePlayer.GetMaxWeight=function()return lOwner.MaxBaseCarryWeight+112.944408 end
    local liveController=controller()
    assert(liveController.apply(livePlayer))
    local nextSettings={}
    for _,name in ipairs(config.names) do nextSettings[name]={Weight='default'} end
    nextSettings.Player.Weight='600'
    local undo=liveController.update(nextSettings)
    assert(math.abs(livePlayer:GetMaxWeight()-600)<0.0001,'Live player update failed')
    undo();assert(math.abs(livePlayer:GetMaxWeight()-300)<0.0001,'Live update rollback failed')
    nextSettings.Player.Weight='default';liveController.update(nextSettings)
    assert(math.abs(livePlayer:GetMaxWeight()-158.303607523926)<0.0001,'Player default was not restored')
    nextSettings.Player.Weight='1';liveController.update(nextSettings)
    assert(math.abs(livePlayer:GetMaxWeight()-1)<0.0001,'Minimum after resetting failed')
    local cratePath=next(classes)
    local crateName=classes[cratePath]
    local crate=inventory(cratePath,100)
    local crateController=controller();assert(crateController.apply(crate))
    nextSettings[crateName].Weight='300';crateController.update(nextSettings)
    assert(math.abs(crate:GetMaxWeight()-300)<0.0001,'Live crate update failed')
    nextSettings[crateName].Weight='default';crateController.update(nextSettings)
    assert(math.abs(crate:GetMaxWeight()-45.3592)<0.0001,'Crate factory default was not restored')
    local initial={};local invalidUpdate={}
    for _,name in ipairs(config.names) do initial[name]={Weight='default'};invalidUpdate[name]={Weight='default'} end
    local atomic=capacity.create(initial,config,classes,function()end,function()end)
    local first=inventory(cratePath,100)
    local second,sOwner=inventory('/Game/Player.Player_C',136.078,true)
    second.GetMaxWeight=function()return 100 end
    assert(atomic.apply(first) and atomic.apply(second))
    invalidUpdate[crateName].Weight='300';invalidUpdate.Player.Weight='300'
    assert(not pcall(atomic.update,invalidUpdate),'Partial update should fail')
    assert(first.MaxWeight==100 and sOwner.MaxBaseCarryWeight==45 and sOwner.MaxCapCarryWeight==181,'Partial update was not rolled back')
    return true
end
