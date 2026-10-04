-- No polling: resolve only the clicked recipe's open station.
return function(network,storage,crafting,radius,log,dispatch)
    local function real(v)return v and v:IsValid() and not v:GetFullName():find('Default__',1,true)end
    local stationClass=StaticFindObject('/Script/Vein.WorkbenchInventoryComponent')
    local recipeClass=StaticFindObject('/Game/Vein/UI/UMG/Crafting/WBP_WorkbenchRecipe.WBP_WorkbenchRecipe_C')
    local classKey=real(recipeClass) and recipeClass:GetFullName():match('^[^ ]+ (.*)$') or '/Game/Vein/UI/UMG/Crafting/WBP_WorkbenchRecipe.WBP_WorkbenchRecipe_C'
    local connectClick;local connected=false
    local function clicked(icon)
        if not real(icon) or not icon:IsVisible() or icon.bInQueue then return end
        local recipe=icon:GetRecipe()
        if not real(recipe) then return end
        local actor
        for _,candidate in ipairs(FindObjects(0,'VeinPlayerCharacter',nil,0,0,false) or {})do
            if real(candidate) and candidate:IsLocallyControlled() and candidate:HasAuthority() then actor=candidate;break end
        end
        if not actor or recipe:NeedsSchematic(actor) then return end
        local windows=FindObjects(0,'BasePlayerInventoryWindowWidget',nil,0,0,false) or {}
        local components
        for _,window in ipairs(windows)do
            if real(window) and window:IsVisible() then
                local path=window:GetFullName():match('^[^ ]+ (.*)$')
                if icon:GetFullName():find(path..'.',1,true) then
                    for _,inventory in ipairs(crafting.values(window:GetInventories()))do
                        if real(inventory) and inventory:IsA(stationClass) then
                            components=components or FindObjects(0,'CraftingComponent',nil,0,0,false) or {}
                            for _,bench in ipairs(components)do
                                if real(bench) then
                                    local owner=bench:GetOwner()
                                    if real(owner) and owner:GetWorld():GetFullName()==actor:GetWorld():GetFullName() and network.in_range(actor:K2_GetActorLocation(),owner:K2_GetActorLocation(),5) then
                                        local contents=bench:GetInventory()
                                        if real(contents) and contents:GetFullName()==inventory:GetFullName() then
                                            -- The native crafting pre-hook makes a fresh material plan
                                            -- and stages only this recipe. Never scan other recipes.
                                            dispatch(actor,bench,recipe)
                                            return
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    RegisterHook('/Script/Vein.RecipeIconUserWidget:SetCraftable',function(context,craftable,needsSchematic)
        local icon=context:get()
        if real(icon) and icon:IsVisible() and icon:GetClass():GetFullName():match('^[^ ]+ (.*)$')==classKey then
            if not connected then connectClick(icon:GetClass()) end
            -- Permit an on-demand check when materials exist only in storage.
            -- Native crafting still enforces quantities, tools, water and skills.
            if not icon.bInQueue and not needsSchematic:get() then craftable:set(true) end
        end
    end)
    connectClick=function(cls)
    if connected then return end
    local count=0
    cls:ForEachFunction(function(fn)
        local name=fn:GetFName():ToString():lower()
        if name:find('bndevt',1,true) and name:find('clicked',1,true) and not name:find('pin',1,true) and not name:find('right',1,true) then
            local path=fn:GetFullName():match('^Function (.*)$')
            if path then
                RegisterHook(path,function(context)
                    local ok,message=pcall(clicked,context:get())
                    if not ok then log('RECIPE CLICK ERROR '..tostring(message))end
                end)
                count=count+1
            end
        end
    end)
    assert(count==1,'Expected exactly one workbench recipe click handler')
    connected=true
    end
    if real(recipeClass) then connectClick(recipeClass) end
    -- Constructor notifications cover all object creation internally. Retain
    -- this listener only until the first recipe menu exists, then unregister.
    NotifyOnNewObject('/Script/Vein.RecipeIconUserWidget',function(icon)
        if not real(icon) or icon:GetClass():GetFullName():match('^[^ ]+ (.*)$')~=classKey then return end
        ExecuteInGameThread(function()
            local ok,message=pcall(function()
                if real(icon) and icon:GetClass():GetFullName():match('^[^ ]+ (.*)$')==classKey then
                    connectClick(icon:GetClass())
                    -- One-time UI setup for this menu; no inventory queries.
                    for _,candidate in ipairs(FindObjects(0,'RecipeIconUserWidget',nil,0,0,false) or {})do
                        if real(candidate) and candidate:IsVisible() and candidate:GetClass():GetFullName():match('^[^ ]+ (.*)$')==classKey and not candidate.bInQueue then
                            candidate:SetCraftable(true,candidate.bNeedsSchematic)
                        end
                    end
                end
            end)
            if not ok then log('RECIPE CREATION ERROR '..tostring(message)) end
        end)
        return true
    end)
    log('On-demand recipe click hook ready; periodic material scanning disabled.')
    return function()end
end
