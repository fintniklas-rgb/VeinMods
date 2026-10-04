-- Storage adapter. Read-only; no transfer or consumption calls.
local M={}
local function valid(object) return object and object:IsValid() end
local function supported(owner)
    -- Explicitly verified live actor types; expand only after testing.
    local cls=owner:GetClass()
    while valid(cls) do
        local name=cls:GetFName():ToString()
        if name=='BP_Crate02_C' or name=='BP_Fridge_Residential_C' then return true end
        cls=cls:GetSuperStruct()
    end
    return false
end
function M.discover(actor,origin,radius,network)
    local result={};local seen={}
    local world=actor:GetWorld():GetFullName()
    for _,inventory in ipairs(FindObjects(0,'BaseInventoryComponent',nil,0,0,false) or {}) do
        if valid(inventory) and not inventory:GetFullName():find('Default__',1,true) then
            local owner=inventory:GetOwner()
            if valid(owner) and owner:GetWorld():GetFullName()==world and network.in_range(origin,inventory:GetLocation(),radius) and not inventory:HasLock() and supported(owner) then
                local name=inventory:GetFullName()
                if not seen[name] then
                    result[#result+1]=inventory;seen[name]=true
                end
            end
        end
    end
    table.sort(result,function(a,b)return a:GetFullName()<b:GetFullName() end)
    return result
end
return M
