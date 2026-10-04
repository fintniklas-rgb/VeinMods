local M = {}
local function exists(path) local f=io.open(path,'rb');if f then f:close();return true end;return false end
local function read(path,limit)
    local file=io.open(path,'rb');if not file then return '' end
    local size=file:seek('end') or 0;file:seek('set',math.max(0,size-(limit or 2097152)))
    local content=file:read('*a') or '';file:close();return content
end
local function session(log)
    local start=1
    for position in log:gmatch('()Console created') do start=position end
    return log:sub(start)
end
function M.collect(root,decode,attached)
    local ue=root..'\\Vein\\Binaries\\Win64\\ue4ss'
    local log=session(read(ue..'\\UE4SS.log'))
    local game=read(root..'\\Vein\\Saved\\Logs\\Vein.log')
    local mounted={}
    for line in game:gmatch('[^\r\n]+') do
        if line:find('Mounted Pak file',1,true) then
            local name=line:match('[/\\]([^/\\]+%.pak)')
            if name then mounted[name]=true end
        end
    end
    local rows,known={},{}
    local function add(key,name,kind,color,detail)
        if not known[key] then known[key]=true;rows[#rows+1]={name=name,kind=kind,color=color,detail=detail} end
    end
    local function lua(name)
        if name=='VeinModsMenu' then add('lua:'..name,name,'Lua',attached and 'green' or 'red',attached and 'Menu UI attached' or 'Menu UI unavailable');return end
        local entry=ue..'\\Mods\\'..name..'\\Scripts\\main.lua'
        local dll=ue..'\\Mods\\'..name..'\\dlls\\main.dll'
        if not exists(entry) and not exists(dll) then add('lua:'..name,name,'UE4SS','red','Entry file missing');return end
        if name=='CustomStorage' or name=='CraftFromContainer' then
            local ok,ready=pcall(function()return ModRef:GetSharedVariable('VeinConfig.'..name..'.Ready') end)
            add('lua:'..name,name,'UE4SS',ok and ready==true and 'green' or 'red',ok and ready==true and 'Mod loaded' or 'Mod not loaded');return
        end
        for line in log:gmatch('[^\r\n]+') do
            local normalized=line:lower():gsub('\\','/')
            if (normalized:find('error',1,true) or normalized:find('failed',1,true)) and normalized:find('mods/'..name:lower()..'/',1,true) then
                add('lua:'..name,name,'UE4SS','red','Loader reported an error');return
            end
        end
        local started=log:find("Starting Lua mod '"..name.."'",1,true) or log:find("Starting C++ mod '"..name.."'",1,true)
        add('lua:'..name,name,'UE4SS',started and 'green' or 'red',started and 'Mod loaded' or 'Mod not loaded')
    end
    local list=read(ue..'\\Mods\\mods.txt',1048576)
    local configured={}
    for line in list:gmatch('[^\r\n]+') do
        local name,flag=line:match('^%s*([%w_%-]+)%s*:%s*([01])')
        if name then configured[name]=flag=='1' end
    end
    local library=read(root..'\\.VeinModManager\\mods.json',16777216)
    if library~='' then
        local ok,mods=pcall(decode,library)
        if ok and type(mods)=='table' then
            for _,mod in ipairs(mods) do
                if mod.Enabled==true then
                    if mod.Type=='Lua' and type(mod.Folder)=='string' then lua(mod.Folder)
                    elseif mod.Type=='PAK' or mod.Type=='LogicMod' then
                        local color,detail='green','PAK mounted; gameplay not self-tested'
                        for _,file in ipairs(mod.Files or {}) do
                            local path=root..'\\Vein\\Content\\Paks\\'..(mod.Type=='LogicMod' and 'LogicMods\\' or '')..file.Relative
                            if not exists(path) then color,detail='red','Enabled PAK file missing';break end
                            if not mounted[file.Relative] then color,detail='red','PAK not mounted' end
                            known['pak:'..file.Relative]=true
                        end
                        add('managed:'..tostring(mod.Id),mod.Name or mod.Id,mod.Type,color,detail)
                    end
                elseif mod.Type=='Lua' and type(mod.Folder)=='string' then
                    add('lua:'..mod.Folder,mod.Folder,'UE4SS','red','Mod disabled')
                elseif mod.Type=='PAK' or mod.Type=='LogicMod' then
                    add('managed:'..tostring(mod.Id),mod.Name or mod.Id,mod.Type,'red','Mod disabled')
                end
            end
        else add('library-error','Mod library','Manager','red','Could not read mods.json') end
    end
    for name,enabled in pairs(configured) do
        if enabled or exists(ue..'\\Mods\\'..name..'\\enabled.txt') then lua(name) end
    end
    for name in log:gmatch("Starting Lua mod '([^']+)'") do
        if configured[name]~=false or exists(ue..'\\Mods\\'..name..'\\enabled.txt') then lua(name) end
    end
    for line in game:gmatch('[^\r\n]+') do
        if line:find('Mounted Pak file',1,true) then
            local name=line:match('[/\\]([^/\\]+%.pak)')
            if name and not name:lower():match('^pakchunk') then add('pak:'..name,name,'PAK','green','PAK mounted; gameplay not self-tested') end
        end
    end
    table.sort(rows,function(a,b)return a.name:lower()<b.name:lower() end)
    return rows
end
return M
