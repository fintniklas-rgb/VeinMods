-- VEIN Mods Menu 0.5.1: Settings lifecycle tracking without repeated object searches.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('/','\\')
local scripts=source:match('^(.*)\\[^\\]+$') or '.\\Mods\\VeinModsMenu\\Scripts'
local json=dofile(scripts..'\\json.lua')
local status=dofile(scripts..'\\status.lua')
local root=source:match('^(.*)\\Vein\\Binaries\\Win64\\ue4ss\\Mods\\') or '..\\..\\..\\..'
local state={menu=nil,button=nil,panel=nil,list=nil,close=nil,pressed=false,closePressed=false,open=false,pending=false,attempts=0,diagnosed=false}
local function log(message)
    print('[VeinModsMenu] '..message..'\n')
    local file=io.open(root..'\\.VeinModManager\\mods-menu.log','ab')
    if file then file:write(os.date('%Y-%m-%d %H:%M:%S')..' '..message..'\n');file:close() end
end
local function valid(object) local ok,value=pcall(function()return object and object:IsValid() end);return ok and value end
local function property(object,name) local ok,value=pcall(function()return object[name] end);if ok then return value end end
local function class(name) local value=StaticFindObject('/Script/UMG.'..name);assert(valid(value),'UMG class not found: '..name);return value end
local function isa(object,name) local ok,result=pcall(function()return object:IsA(class(name)) end);return ok and result end
local function create(name,outer)
    local value=StaticConstructObject(class(name),outer);assert(valid(value),'Could not construct '..name);return value
end
local function children(widget)
    local result={}
    if isa(widget,'UserWidget') then
        local tree=property(widget,'WidgetTree');local node=valid(tree) and property(tree,'RootWidget')
        if valid(node) then result[#result+1]=node end
    elseif isa(widget,'PanelWidget') then
        for i=0,widget:GetChildrenCount()-1 do local child=widget:GetChildAt(i);if valid(child) then result[#result+1]=child end end
    end
    return result
end
local function find_button(widget,depth)
    if not valid(widget) or depth>20 then return nil end
    if isa(widget,'Button') then return widget end
    for _,child in ipairs(children(widget)) do local button=find_button(child,depth+1);if button then return button end end
end
local function find_settings(widget,depth)
    if not valid(widget) or depth>25 then return nil end
    if isa(widget,'TextBlock') then
        local ok,label=pcall(function()return widget:GetText():ToString() end)
        if ok and label:lower():match('^%s*settings%s*$') then return widget end
    end
    for _,child in ipairs(children(widget)) do local result=find_settings(child,depth+1);if result then return result end end
end
local function text(outer,value,color,size)
    local widget=create('TextBlock',outer);widget:SetText(FText(value))
    widget:SetFont({FontObject=widget.Font.FontObject,TypefaceFontName=FName('Regular'),Size=size or 18,LetterSpacing=0})
    if color then widget:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0}) end
    pcall(function()widget:SetAutoWrapText(true) end)
    return widget
end
local colors={green={R=0.2,G=0.85,B=0.38,A=1},red={R=1,G=0.27,B=0.22,A=1},gray={R=0.65,G=0.68,B=0.72,A=1}}
local function columns(tree,name,statusText,color,header)
    local row=create('HorizontalBox',tree)
    local left=row:AddChildToHorizontalBox(text(tree,name,header and colors.gray or nil,header and 14 or 18))
    left:SetSize({SizeRule=1,Value=0.65})
    left:SetPadding({Left=0,Top=12,Right=24,Bottom=12})
    local label=text(tree,statusText,color,header and 14 or 18)
    label:SetJustification(2)
    local right=row:AddChildToHorizontalBox(label)
    right:SetSize({SizeRule=1,Value=0.35})
    right:SetPadding({Left=12,Top=12,Right=0,Bottom=12})
    return row
end
local configUI
local function render()
    state.controls={};state.request=nil;state.message=nil;state.fields=nil
    state.list:ClearChildren()
    local tree=state.menu.WidgetTree
    local rows=status.collect(root,json.decode,true)
    if #rows==0 then state.list:AddChild(text(tree,'No mods detected.',colors.gray,18)) end
    for i,row in ipairs(rows) do
        local value=row.color=='green' and 'loaded' or 'inactive'
        local background=create('Border',tree)
        background:SetPadding({Left=16,Top=0,Right=16,Bottom=0})
        background:SetBrushColor(i%2==0 and {R=0.055,G=0.045,B=0.035,A=1} or {R=0.035,G=0.028,B=0.023,A=1})
        local card=create('VerticalBox',tree)
        card:AddChild(columns(tree,row.name,value,colors[row.color],false))
        if configUI.supported(row.name) then card:AddChild(configUI.configure(tree,row.name)) end
        background:SetContent(card)
        background:SetToolTipText(FText(row.kind..': '..row.detail))
        state.list:AddChild(background)
    end
end
local live=dofile(scripts..'\\live-config.lua');assert(live.self_test())
configUI=dofile(scripts..'\\config-ui.lua')({create=create,text=text,valid=valid,state=function()return state end,render=render},live,root)
local function attach(menu)
    local tree=property(menu,'WidgetTree')
    local switcher=property(menu,'Switcher')
    local keyboard=property(menu,'KeyboardButton')
    if not valid(tree) or not valid(switcher) or not valid(keyboard) then return false end
    local tabs=keyboard:GetParent()
    if not valid(tabs) or not isa(tabs,'PanelWidget') then return false end
    assert(isa(tabs,'HorizontalBox') or isa(tabs,'VerticalBox') or isa(tabs,'WrapBox'),'Unsupported Settings tab layout: '..tabs:GetFullName())
    log('Settings tab container: '..tabs:GetFullName())
    log('Settings page switcher: '..switcher:GetFullName())
    local panel=create('Border',tree)
    panel:SetPadding({Left=24,Top=20,Right=24,Bottom=20})
    panel:SetBrushColor({R=0.035,G=0.025,B=0.02,A=0.98})
    local layout=create('VerticalBox',tree);panel:SetContent(layout)
    layout:AddChildToVerticalBox(text(tree,'Mods',nil,28))
    layout:AddChildToVerticalBox(text(tree,'Loaded mods are green. Inactive mods are red. Hover a row for details.',colors.gray,14))
    local header=create('Border',tree);header:SetPadding({Left=16,Top=0,Right=16,Bottom=0});header:SetBrushColor({R=0.075,G=0.06,B=0.045,A=1});header:SetContent(columns(tree,'MOD NAME','STATUS',colors.gray,true));layout:AddChildToVerticalBox(header)
    local scroll=create('ScrollBox',tree)
    layout:AddChildToVerticalBox(scroll):SetSize({SizeRule=1,Value=1})
    local list=create('VerticalBox',tree);scroll:AddChild(list)
    local previous=switcher:GetActiveWidgetIndex()
    local index=switcher:GetChildrenCount()
    switcher:AddChild(panel)
    switcher:SetActiveWidgetIndex(previous)
    local button=create('Button',tree)
    button:SetBackgroundColor({R=0.045,G=0.032,B=0.024,A=1})
    local label=text(tree,'MODS',{R=1,G=1,B=1,A=1},20)
    label:SetAutoWrapText(false)
    local contentSlot=button:SetContent(label)
    contentSlot:SetPadding({Left=18,Top=14,Right=18,Bottom=14})
    contentSlot:SetHorizontalAlignment(2);contentSlot:SetVerticalAlignment(2)
    tabs:AddChild(button)
    state.menu=menu;state.button=button;state.panel=panel;state.list=list
    state.switcher=switcher;state.index=index;state.pressed=false;state.open=false
    local smoke=io.open(root..'\\.VeinModManager\\live-config-smoke.flag','rb')
    if smoke then
        smoke:close();configUI.smoke();log('Live config native widget and cross-mod bridge smoke tests passed.')
    end
    log('Mods appended as the last Settings tab; page index='..tostring(index))
    return true
end
local menus={}
local waiting={}
local initialized=false
local idleMilliseconds=0
local pending=false
local halted=false
local function enqueue(menu)
    waiting[#waiting+1]=menu
    idleMilliseconds=0
end
local function tick()
    if not initialized then
        initialized=true
        -- Covers objects created before notification registration. Never repeat this search.
        for _,menu in ipairs(FindObjects(0,'SettingsUserWidget',nil,0,0,false) or {}) do enqueue(menu) end
    end
    for i=#waiting,1,-1 do
        local menu=waiting[i]
        if not valid(menu) then table.remove(waiting,i)
        else
            local name=menu:GetFullName()
            local known=name:find('Default__',1,true)
            for _,entry in ipairs(menus) do if entry.name==name then known=true;break end end
            if known then table.remove(waiting,i)
            elseif valid(property(menu,'WidgetTree')) and valid(property(menu,'KeyboardButton')) then
                local ok,result=pcall(attach,menu)
                if not ok then error('Settings attach failed: '..tostring(result)) end
                if result then
                    menus[#menus+1]={name=name,menu=state.menu,button=state.button,panel=state.panel,list=state.list,switcher=state.switcher,index=state.index,pressed=false}
                    table.remove(waiting,i)
                end
            end
        end
    end
    local visible=false
    for i=#menus,1,-1 do
        local entry=menus[i]
        if not valid(entry.menu) or not valid(entry.button) or not valid(entry.switcher) then table.remove(menus,i)
        elseif entry.menu:IsVisible() then
            visible=true
            state=entry
            local pressed=entry.button:IsPressed()
            if pressed and not entry.pressed and not entry.request then
                render()
                entry.switcher:SetActiveWidgetIndex(entry.index)
                log('Mods Settings page selected.')
            end
            entry.pressed=pressed
            if entry.switcher:GetActiveWidgetIndex()==entry.index then configUI.tick(entry) end
        else
            entry.pressed=false
            for _,control in ipairs(entry.controls or {}) do control.pressed=false end
        end
    end
    return visible
end
-- Construction callbacks retain references only; UMG calls stay on the game thread.
NotifyOnNewObject('/Script/Vein.SettingsUserWidget',function(menu) enqueue(menu) end)
log('Loaded 0.5.1; Settings lifecycle tracking enabled. No save data will be modified.')
LoopAsync(40,function()
    if halted then return true end
    if idleMilliseconds>0 then idleMilliseconds=idleMilliseconds-40;return false end
    if pending then return false end
    pending=true
    ExecuteInGameThread(function()
        local ok,visible=pcall(tick);pending=false
        -- Hidden menus: only cached validity/visibility checks, twice per second.
        idleMilliseconds=visible and 0 or 480
        if not ok then log('UI tick failed: '..tostring(visible));halted=true end
    end)
    return false
end)
