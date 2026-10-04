return function(factory,network,crafting)
    local oldFind,oldHook,oldStatic=FindObjects,RegisterHook,StaticFindObject
    local oldNotify,oldExecute=NotifyOnNewObject,ExecuteInGameThread;local creation
    NotifyOnNewObject=function(_,callback)creation=callback end
    ExecuteInGameThread=function(callback)callback()end
    local hooks={};local scans=0;local requests=0;local menuOpen=true;local needs=false;local distance=0;local errors={}
    local function obj(name)return {IsValid=function()return true end,GetFullName=function()return name end,IsVisible=function()return true end}end
    local world=obj('World TestWorld')
    local actor=obj('Player World.Player');actor.IsLocallyControlled=function()return true end;actor.HasAuthority=function()return true end
    actor.GetWorld=function()return world end;actor.K2_GetActorLocation=function()return {X=distance,Y=0,Z=0}end
    local inventory=obj('WorkbenchInventoryComponent World.Station.Inventory');inventory.IsA=function()return true end
    local owner=obj('Actor World.Station');owner.GetWorld=function()return world end;owner.K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end
    local bench=obj('CraftingComponent World.Station.Crafting');bench.GetOwner=function()return owner end;bench.GetInventory=function()return inventory end
    local window=obj('Window World.Window');window.IsVisible=function()return menuOpen end;window.GetInventories=function()return {{get=function()return inventory end}}end
    local recipe=obj('Recipe Nails');recipe.NeedsSchematic=function()return needs end
    local cls=obj('Class /Game/Test.WBP_Recipe_C')
    local fn={GetFullName=function()return 'Function /Game/Test.WBP_Recipe_C:BndEvt__Recipe_Button_OnClicked'end,GetFName=function()return {ToString=function()return 'BndEvt__Recipe_Button_OnClicked'end}end}
    cls.ForEachFunction=function(_,callback)callback(fn)end
    local icon=obj('RecipeIcon World.Window.WidgetTree.Nails');icon.GetRecipe=function()return recipe end;icon.GetClass=function()return cls end
    RegisterHook=function(path,callback)hooks[path]=callback end
    StaticFindObject=function()return cls end
    FindObjects=function(_,class)
        scans=scans+1
        if class=='VeinPlayerCharacter' then return {actor} end
        if class=='BasePlayerInventoryWindowWidget' then return {window} end
        if class=='CraftingComponent' then return {bench} end
        if class=='RecipeIconUserWidget' then return {icon} end
        error('Unexpected recipe-wide object scan: '..class)
    end
    local ok,message=pcall(function()
        local update=factory(network,{discover=function()error('Storage scanned outside native crafting click')end},{values=crafting.values,plan=function()error('Recipe availability eagerly planned materials')end},100,function(message)errors[#errors+1]=message end,function(a,b,r)assert(a==actor and b==bench and r==recipe);requests=requests+1 end)
        for _=1,20 do update() end
        assert(scans==0,'Idle/open-menu updates scanned the world')
        local parameter={value=false,set=function(self,value)self.value=value end}
        local status=hooks['/Script/Vein.RecipeIconUserWidget:SetCraftable']
        status({get=function()return icon end},parameter,{get=function()return false end})
        assert(parameter.value,'Remote-only material recipes cannot be clicked')
        assert(scans==0,'Recipe presentation scanned the world')
        parameter.value=false;status({get=function()return icon end},parameter,{get=function()return true end});assert(not parameter.value,'Missing schematic was bypassed')
        local click=hooks['/Game/Test.WBP_Recipe_C:BndEvt__Recipe_Button_OnClicked'];assert(click)
        click({get=function()return icon end});assert(requests==1,'Clicked recipe did not reach native crafting')
        local before=scans;for _=1,20 do update()end;assert(scans==before,'In-progress crafting caused periodic scans')
        assert(creation,'Late-created recipe widgets were not registered')
        cls.GetFullName=function()return 'WidgetBlueprintGeneratedClass /Game/Test.WBP_Recipe_C'end
        icon.SetCraftable=function(self,value,needsSchematic)
            local parameter={value=value,set=function(self,value)self.value=value end}
            status({get=function()return self end},parameter,{get=function()return needsSchematic end})
            self.enabled=parameter.value
        end
        assert(creation(icon)==true,'Constructor listener did not unregister after first menu')
        assert(icon.enabled and scans==before+1,'One-time recipe UI setup did not complete')
        before=scans;for _=1,20 do update()end;assert(scans==before,'UI setup introduced periodic scanning')
        icon.IsVisible=function()return false end
        parameter.value=false;status({get=function()return icon end},parameter,{get=function()return false end});assert(not parameter.value,'Hidden recipe received a CraftFromContainer update')
        icon.IsVisible=function()return true end
        menuOpen=false;click({get=function()return icon end});assert(requests==1,'Closed menu dispatched a recipe')
        menuOpen=true;distance=1000;click({get=function()return icon end});assert(requests==1,'Distant station dispatched a recipe')
        distance=0;needs=true;click({get=function()return icon end});assert(requests==1,'Missing schematic dispatched a recipe')
        for _,message in ipairs(errors)do assert(not message:find('ERROR',1,true),message)end
    end)
    FindObjects,RegisterHook,StaticFindObject=oldFind,oldHook,oldStatic
    NotifyOnNewObject,ExecuteInGameThread=oldNotify,oldExecute
    assert(ok,message);return true
end
