local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('/','\\')
local scripts=assert(source:match('^(.*)\\[^\\]+$'))
local folder=assert(scripts:match('^(.*)\\Scripts$'))
local function log(message)
    print('[CustomStorage] '..message..'\n')
    local file=io.open(folder..'\\CustomStorage.log','ab')
    if file then file:write(os.date('%Y-%m-%d %H:%M:%S')..' '..message..'\n');file:close() end
end
local config=dofile(scripts..'\\config.lua')
assert(config.self_test())
local path=folder..'\\config.ini'
local function read()
    local file=assert(io.open(path,'rb'),'Cannot read config.ini')
    local contents=file:read('*a');file:close();return contents
end
local settings=config.parse(read())
for _,name in ipairs(config.names) do config.validate(settings[name].Weight) end
local function record(name,base)
    local contents,changed=config.record(read(),name,base)
    if changed then
        local file=assert(io.open(path,'wb'),'Cannot write detected BaseWeight to config.ini')
        file:write(contents);file:close()
    end
end
local classes=dofile(scripts..'\\classes.lua')
local capacity=dofile(scripts..'\\capacity.lua')
assert(dofile(scripts..'\\tests.lua')(config,capacity,classes))
local controller=capacity.create(settings,config,classes,record,log)
local live=dofile(scripts..'\\live-config.lua');assert(live.self_test())
local bridge=live.start('CustomStorage',path,function(contents)return controller.update(config.parse(contents))end,log)
local pending={};local scheduled=false
local function enqueue(inv)
    pending[#pending+1]={object=inv,wait=8}
end
NotifyOnNewObject('/Script/Vein.BaseInventoryComponent',function(inv)enqueue(inv)end)
local initialized=false
LoopAsync(250,function()
    if initialized and #pending==0 and not bridge.pending() then return false end
    if scheduled then return false end
    scheduled=true
    ExecuteInGameThread(function()
        local ok,err=pcall(function()
            bridge.poll()
            if not initialized then
                initialized=true
                -- One compatibility scan, including inventories present before mod initialization.
                for _,inv in ipairs(FindObjects(0,'BaseInventoryComponent',nil,0,0,false) or {}) do enqueue(inv) end
            end
            local handled=0
            for i=#pending,1,-1 do
                local entry=pending[i]
                entry.wait=entry.wait-1
                if entry.wait<=0 and handled<32 then
                    table.remove(pending,i);handled=handled+1
                    local success,message=pcall(controller.apply,entry.object)
                    if not success then log('ERROR '..tostring(message)) end
                end
            end
        end)
        scheduled=false
        if not ok then log('ERROR processing new inventories: '..tostring(err)) end
    end)
    return false
end)
log('Loaded 0.2.0. Config and capacity tests passed; inventory lifecycle updates enabled, no periodic world searches.')
