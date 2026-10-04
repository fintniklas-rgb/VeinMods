return function(env,live,root)
    local M={};local serial=0
    local function state()return env.state()end
    local function track(widget,action)
        local entry=state();entry.controls=entry.controls or {}
        entry.controls[#entry.controls+1]={widget=widget,action=action,pressed=false}
    end
    local function button(tree,label,action)
        local widget=env.create('Button',tree)
        widget:SetBackgroundColor({R=0.075,G=0.06,B=0.045,A=1})
        local slot=widget:SetContent(env.text(tree,label,nil,16))
        slot:SetPadding({Left=14,Top=8,Right=14,Bottom=8})
        track(widget,action);return widget
    end
    local function message(entry,value,error)
        if env.valid(entry.message) then
            entry.message:SetText(FText(value))
            entry.message:SetColorAndOpacity({SpecifiedColor=error and {R=1,G=0.27,B=0.22,A=1} or {R=0.2,G=0.85,B=0.38,A=1},ColorUseRule=0})
        end
    end
    function M.supported(name)
        return (name=='CustomStorage' or name=='CraftFromContainer') and ModRef:GetSharedVariable('VeinConfig.'..name..'.Ready')==true
    end
    function M.open(name)
        local entry=state()
        entry.list:ClearChildren();entry.controls={};entry.request=nil
        local tree=entry.menu.WidgetTree
        local path=root..'\\Vein\\Binaries\\Win64\\ue4ss\\Mods\\'..name..'\\config.ini'
        local contents=live.read(path)
        local fields=live.fields(name,contents)
        entry.list:AddChild(env.text(tree,name..' Settings',nil,24))
        entry.list:AddChild(env.text(tree,name=='CustomStorage' and 'Enter a weight in kg, or "default". Changes apply when you press Save & Apply.' or 'Enter the storage search distance in metres (1–1000). Applies to the next crafting click.',nil,14))
        for _,field in ipairs(fields) do
            local row=env.create('HorizontalBox',tree)
            local label=env.create('VerticalBox',tree)
            label:AddChild(env.text(tree,field.label,nil,18))
            label:AddChild(env.text(tree,'Base: '..field.base..' '..field.unit,nil,14))
            local left=row:AddChildToHorizontalBox(label)
            left:SetSize({SizeRule=1,Value=0.7});left:SetPadding({Left=0,Top=8,Right=24,Bottom=8})
            local input=env.create('EditableTextBox',tree)
            local initial=field.value
            local factor=initial:match('^([%d%.]+)x$')
            if factor and tonumber(field.base) then initial=tostring(tonumber(factor)*tonumber(field.base)) end
            input:SetText(FText(initial));input:SetHintText(FText(field.unit))
            local right=row:AddChildToHorizontalBox(input)
            right:SetSize({SizeRule=1,Value=0.3});right:SetPadding({Left=0,Top=8,Right=0,Bottom=8})
            field.input=input;entry.list:AddChild(row)
        end
        entry.fields=fields
        entry.message=env.text(tree,'Changes are saved only after successful application.',nil,14)
        entry.list:AddChild(entry.message)
        local actions=env.create('HorizontalBox',tree)
        local save=button(tree,'Save & Apply',function()
            if entry.request then message(entry,'An update is already pending.',true);return end
            assert(M.supported(name),'Mod configuration is not ready')
            local updated=contents
            for _,field in ipairs(fields) do
                local value=field.input:GetText():ToString():match('^%s*(.-)%s*$')
                if value~='default' or name~='CustomStorage' then live.number(value,field.min,field.max) end
                updated=live.set(updated,field.section,field.key,value)
            end
            live.validate(name,updated)
            assert(live.read(path)==contents,'Config changed on disk. Reopen this page before saving.')
            serial=serial+1
            local id=tostring(os.time())..':'..serial
            entry.request={id=id,name=name,contents=updated,accepted=function()contents=updated end}
            ModRef:SetSharedVariable('VeinConfig.'..name..'.Request',id..'\n'..updated)
            message(entry,'Applying settings...',false)
        end)
        actions:AddChildToHorizontalBox(save):SetPadding({Left=0,Top=12,Right=12,Bottom=12})
        actions:AddChildToHorizontalBox(button(tree,'Reset to Default',function()
            if entry.request then return end
            for _,field in ipairs(fields) do field.input:SetText(FText(field.default)) end
            message(entry,'Defaults selected. Press Save & Apply to save them.',false)
        end)):SetPadding({Left=0,Top=12,Right=12,Bottom=12})
        actions:AddChildToHorizontalBox(button(tree,'Back to Mods',function()
            if entry.request then message(entry,'Wait for the update to finish.',true);return end
            env.render()
        end)):SetPadding({Left=0,Top=12,Right=0,Bottom=12})
        entry.list:AddChild(actions)
    end
    function M.configure(tree,name)
        return button(tree,'Configure',function()M.open(name)end)
    end
    function M.smoke()
        assert(M.supported('CustomStorage') and M.supported('CraftFromContainer'),'Cross-mod bridge unavailable')
        M.open('CustomStorage')
        assert(#state().controls==3,'Config actions missing')
        for _,field in ipairs(state().fields) do assert(field.input:GetText():ToString()~='','Weight field text unavailable') end
        M.open('CraftFromContainer')
        assert(#state().controls==3,'Radius actions missing')
        assert(state().fields[1].input:GetText():ToString()~='','Radius field text unavailable')
        env.render()
    end
    function M.tick(entry)
        if entry.request then
            local request=entry.request
            local ack=ModRef:GetSharedVariable('VeinConfig.'..request.name..'.Ack')
            if type(ack)=='string' then
                local id,result=ack:match('^([^\n]+)\n(.*)$')
                if id==request.id then
                    local ok=result:sub(1,3)=='OK '
                    if ok then request.accepted() end
                    message(entry,result:sub(ok and 4 or 7),not ok)
                    entry.request=nil
                end
            end
        end
        -- Snapshot prevents callbacks that rebuild the page from altering this iteration.
        local controls={}
        for _,control in ipairs(entry.controls or {}) do controls[#controls+1]=control end
        for _,control in ipairs(controls) do
            if env.valid(control.widget) then
                local pressed=control.widget:IsPressed()
                if pressed and not control.pressed then
                    local ok,err=pcall(control.action)
                    if not ok then message(entry,tostring(err),true) end
                end
                control.pressed=pressed
            end
        end
    end
    return M
end
