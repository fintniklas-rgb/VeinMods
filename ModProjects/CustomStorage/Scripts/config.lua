local M={}
M.names={'Small Crate','Large Crate','Wood Log Storage','Wooden Plank Storage','Scrap Storage','Standard Workbench','Advanced Workbench','Fabrication Workbench','Player'}
local function trim(s) return s:match('^%s*(.-)%s*$') end
function M.parse(contents)
    local result={};local section
    for line in (contents..'\n'):gmatch('(.-)\n') do
        line=trim(line:gsub('\r',''))
        if line~='' and not line:match('^[;#]') then
            local name=line:match('^%[(.-)%]$')
            if name then
                assert(not result[name],'Duplicate config section: '..name)
                result[name]={};section=result[name]
            else
                local key,value=line:match('^([%w_]+)%s*=%s*(.-)%s*$')
                assert(section and key,'Invalid config line: '..line)
                assert(section[key]==nil,'Duplicate config key: '..key)
                section[key]=value
            end
        end
    end
    for _,name in ipairs(M.names) do assert(result[name] and result[name].Weight,'Missing Weight setting for '..name) end
    return result
end
function M.validate(setting)
    if setting:lower()=='default' then return end
    local multiplier=setting:lower():match('^([%d%.]+)%s*x$')
    local value=tonumber(multiplier or setting)
    assert(value and value==value and value<math.huge and (multiplier and value>0 or not multiplier and value>=1),'Weight must be a finite number >= 1, default, or a positive multiplier such as 3x')
end
function M.target(setting,base)
    M.validate(setting)
    if setting:lower()=='default' then return nil end
    local multiplier=setting:lower():match('^([%d%.]+)%s*x$')
    local value=multiplier and tonumber(multiplier)*base or tonumber(setting)
    assert(value and value==value and value<math.huge and value>=1,'Weight must be a finite number >= 1, default, or a multiplier such as 3x')
    return value
end
function M.record(contents,name,base)
    local current;local changed=false;local lines={}
    for line in (contents..'\n'):gmatch('(.-)\n') do
        current=line:match('^%s*%[(.-)%]%s*$') or current
        if current==name and line:match('^%s*BaseWeight%s*=%s*auto%s*\r?$') then
            line='BaseWeight='..string.format('%.6f',base):gsub('0+$',''):gsub('%.$','')
            changed=true
        end
        lines[#lines+1]=line
    end
    return table.concat(lines,'\n'),changed
end
function M.self_test()
    assert(M.target('default',100)==nil)
    assert(M.target('1',100)==1)
    assert(M.target('3x',100)==300)
    assert(M.target('0.5x',100)==50)
    assert(M.target('500',100)==500)
    for _,value in ipairs({'0','-1','abc','nan','inf','0x'}) do assert(not pcall(M.target,value,100)) end
    local updated,changed=M.record('[Small Crate]\nBaseWeight=auto\nWeight=3x\n[Large Crate]\nBaseWeight=auto','Small Crate',123.5)
    assert(changed and updated:find('BaseWeight=123.5',1,true) and updated:find('[Large Crate]\nBaseWeight=auto',1,true))
    local again,second=M.record(updated,'Small Crate',999)
    assert(not second and again:find('BaseWeight=123.5',1,true))
    return true
end
return M
