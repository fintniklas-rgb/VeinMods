-- Shared protocol and INI helpers. Each mod runs its own copy in its own Lua state.
local M={}
M.names={'Small Crate','Large Crate','Wood Log Storage','Wooden Plank Storage','Scrap Storage','Standard Workbench','Advanced Workbench','Fabrication Workbench','Player'}
function M.read(path)
    local f=assert(io.open(path,'rb'),'Cannot read config file')
    local s=f:read('*a');f:close();return s
end
function M.get(contents,section,key)
    local current
    for line in (contents..'\n'):gmatch('(.-)\n') do
        current=line:match('^%s*%[(.-)%]%s*$') or current
        if current==section then
            local k,v=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            if k==key then return v end
        end
    end
end
function M.set(contents,section,key,value)
    local current;local count=0;local result={}
    for line in (contents..'\n'):gmatch('(.-)\n') do
        current=line:match('^%s*%[(.-)%]%s*$') or current
        local k=line:match('^%s*([%w_]+)%s*=')
        if current==section and k==key then line=key..'='..value;count=count+1 end
        result[#result+1]=line
    end
    assert(count==1,'Expected one '..section..'.'..key)
    return table.concat(result,'\n')
end
function M.number(value,min,max)
    local n=tonumber(value)
    assert(n and n==n and n<math.huge and n>=min and (not max or n<=max),'Enter a number from '..min..(max and ' to '..max or ' or higher'))
    return n
end
function M.fields(name,contents)
    local fields={}
    if name=='CustomStorage' then
        for _,section in ipairs(M.names) do
            local base=M.get(contents,section,'BaseWeight') or 'unknown'
            fields[#fields+1]={section=section,key='Weight',label=section,base=base,unit='kg',value=assert(M.get(contents,section,'Weight')),default='default',min=1}
        end
    elseif name=='CraftFromContainer' then
        fields[1]={section='Storage',key='RadiusMetres',label='Storage search distance',base='100',unit='m',value=assert(M.get(contents,'Storage','RadiusMetres')),default='100',min=1,max=1000}
    else error('This mod does not support live configuration') end
    return fields
end
function M.validate(name,contents)
    for _,field in ipairs(M.fields(name,contents)) do
        if field.value~='default' or name~='CustomStorage' then M.number(field.value,field.min,field.max) end
    end
    return contents
end
function M.save(path,contents)
    local temp=path..'.live-tmp';local backup=path..'.live-backup'
    local previous=io.open(backup,'rb')
    if previous then previous:close();error('A previous config recovery file exists') end
    local f=assert(io.open(temp,'wb'),'Cannot write config')
    local ok,err=f:write(contents);local closed,closeError=f:close();assert(ok,err);assert(closed,closeError)
    local moved,problem=os.rename(path,backup)
    if not moved then os.remove(temp);error(problem) end
    local installed,message=os.rename(temp,path)
    if not installed then os.rename(backup,path);os.remove(temp);error(message) end
    os.remove(backup)
end
function M.start(name,path,apply,log)
    local prefix='VeinConfig.'..name..'.'
    ModRef:SetSharedVariable(prefix..'Ready',true)
    ModRef:SetSharedVariable(prefix..'Request',nil)
    ModRef:SetSharedVariable(prefix..'Ack',nil)
    return {
        pending=function()return type(ModRef:GetSharedVariable(prefix..'Request'))=='string' end,
        poll=function()
            local request=ModRef:GetSharedVariable(prefix..'Request')
            if type(request)~='string' then return end
            ModRef:SetSharedVariable(prefix..'Request',nil)
            local id,contents=request:match('^([^\n]+)\n(.*)$')
            if not id then return end
            local undo
            local ok,result=pcall(function()
                M.validate(name,contents)
                local message
                undo,message=apply(contents)
                assert(type(undo)=='function','Live update must support rollback')
                M.save(path,contents)
                return message or 'Saved and applied.'
            end)
            if not ok and undo then
                local restored,err=pcall(undo)
                if not restored then result=tostring(result)..'; rollback failed: '..tostring(err) end
            end
            ModRef:SetSharedVariable(prefix..'Ack',id..'\n'..(ok and 'OK ' or 'ERROR ')..tostring(result))
            log((ok and 'Live config applied: ' or 'LIVE CONFIG ERROR ')..tostring(result))
        end,
    }
end
function M.self_test()
    local s='; comment\n[Storage]\nRadiusMetres=100\n[Diagnostics]\nVerboseLogging=false'
    local updated=M.set(s,'Storage','RadiusMetres','200')
    assert(M.get(updated,'Storage','RadiusMetres')=='200' and M.get(updated,'Diagnostics','VerboseLogging')=='false')
    assert(M.validate('CraftFromContainer',updated))
    assert(not pcall(M.validate,'CraftFromContainer',M.set(s,'Storage','RadiusMetres','0')))
    assert(not pcall(M.number,'nan',1))
    return true
end
return M
