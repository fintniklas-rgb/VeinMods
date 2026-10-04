-- Pure planning: this module never writes to game inventories.
local M={}
function M.in_range(origin,position,radius_metres)
    local dx,dy,dz=position.X-origin.X,position.Y-origin.Y,position.Z-origin.Z
    return dx*dx+dy*dy+dz*dz<=(radius_metres*100)^2
end
function M.plan(requirements,inventories)
    local available={};local result={consume={},tools={}}
    for _,inventory in ipairs(inventories) do
        for _,stack in ipairs(inventory.stacks) do
            assert(stack.amount>=0 and stack.id and stack.kind,'Invalid inventory snapshot')
            available[#available+1]={inventory=inventory.id,stack=stack.id,key=stack.key,kind=stack.kind,amount=stack.amount}
        end
    end
    -- Reserve tools first so a required tool cannot also be consumed as material.
    for _,requirement in ipairs(requirements) do
        if requirement.kind=='tool' then
            local remaining=requirement.amount or 1
            for _,stack in ipairs(available) do
                if stack.key==requirement.key and stack.kind=='item' and remaining>0 then
                    local amount=math.min(remaining,stack.amount)
                    if amount>0 then
                        result.tools[#result.tools+1]={inventory=stack.inventory,stack=stack.stack,amount=amount}
                        stack.amount=stack.amount-amount;remaining=remaining-amount
                    end
                end
            end
            if remaining>0 then return nil,'Missing tool: '..requirement.key end
        end
    end
    for _,requirement in ipairs(requirements) do
        if requirement.kind~='tool' then
            assert(requirement.amount and requirement.amount>0,'Invalid requirement amount')
            local remaining=requirement.amount
            for _,stack in ipairs(available) do
                if stack.key==requirement.key and stack.kind==requirement.kind and remaining>0 then
                    local amount=math.min(remaining,stack.amount)
                    if amount>0 then
                        result.consume[#result.consume+1]={inventory=stack.inventory,stack=stack.stack,amount=amount,kind=stack.kind}
                        stack.amount=stack.amount-amount;remaining=remaining-amount
                    end
                end
            end
            if remaining>0.000001 then return nil,'Missing '..requirement.kind..': '..requirement.key end
        end
    end
    return result
end
function M.self_test()
    local origin={X=0,Y=0,Z=0}
    assert(M.in_range(origin,{X=10000,Y=0,Z=0},100))
    assert(not M.in_range(origin,{X=10001,Y=0,Z=0},100))
    local stores={{id='chest',stacks={{id='a',kind='item',key='wood',amount=3},{id='t',kind='item',key='hammer',amount=1}}},{id='fridge',stacks={{id='b',kind='item',key='wood',amount=2},{id='w',kind='fluid',key='water',amount=0.5}}}}
    local plan=assert(M.plan({{kind='item',key='wood',amount=5},{kind='tool',key='hammer',amount=1},{kind='fluid',key='water',amount=0.5}},stores))
    assert(#plan.consume==3 and #plan.tools==1)
    assert(stores[1].stacks[1].amount==3,'Planner modified its input')
    assert(not M.plan({{kind='item',key='wood',amount=6}},stores))
    assert(not M.plan({{kind='item',key='wood',amount=3},{kind='item',key='wood',amount=3}},stores))
    assert(not M.plan({{kind='tool',key='hammer',amount=1},{kind='item',key='hammer',amount=1}},stores))
    return true
end
return M
