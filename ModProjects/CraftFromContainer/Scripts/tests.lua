return function(crafting)
 local nextID=1000
 local function array(items)return {ForEach=function(_,fn)for i,item in ipairs(items)do fn(i,{get=function()return item end})end end,GetArrayNum=function()return #items end}end
 local function item(kind,count,id)return {kind=kind,Stack=count,ID={Data=id},metadata='preserved:'..kind}end
 local function inventory(items)
  local inv={items=items,merge=true,IsValid=function()return true end,HasLock=function()return false end}
  function inv:GetFullName()return tostring(self)end
  inv.Items=setmetatable({},{__index=function(_,key)if key=='Items' then for _,v in ipairs(inv.items)do v.Inventory=inv end;return array(inv.items)end end})
  function inv:GetItemsOfClass(kind)local r={};for _,v in ipairs(self.items)do if v.kind==kind then r[#r+1]=v end end;return array(r)end
  inv.GetItemsOfTag=inv.GetItemsOfClass
  function inv:GetItemByID()error('Unsafe native ID lookup forbidden')end
  function inv:TransferMyItemTo()error('Nested transfer request forbidden')end
  return inv
 end
 local function count(inv,kind)local n=0;for _,v in ipairs(inv.items)do if v.kind==kind then n=n+v.Stack;assert(v.metadata=='preserved:'..kind)end end;return n end
 local function recipe(requirements,tags)
  local r={PossibleIngredients=array({{}})}
  function r:GetIngredientsForSet()return {bEnabled=true,Ingredients=requirements,IngredientTags=tags or {}}end
  return r
 end
 local function session(benchItems)
  local benchInv=inventory(benchItems or {})
  local actor={calls=0,GetInventory=function()error('Workbench crafting must not use player inventory')end}
  function actor:Server_TransferOneStack(live,destination)
   self.calls=self.calls+1;local source=live.Inventory
   assert(source and source~=destination)
   if destination==benchInv and self.rejectKind==live.kind then return end
   -- Observed game behavior: one unit, with a new destination ID or merge.
   local kind,metadata=live.kind,live.metadata
   live.Stack=live.Stack-1
   if live.Stack==0 then for i,v in ipairs(source.items)do if v==live then table.remove(source.items,i);break end end end
   local target=nil
   if destination.merge then for _,v in ipairs(destination.items)do if v.kind==kind and v.metadata==metadata then target=v;break end end end
   if target then target.Stack=target.Stack+1
   else nextID=nextID+1;local v=item(kind,1,nextID);v.Inventory=destination;destination.items[#destination.items+1]=v end
  end
  return actor,{GetInventory=function()return benchInv end},benchInv
 end
 local logs={};local function log(v)logs[#logs+1]=v end
 -- Cloth Rope: exactly two units from a stack of 99, both merged/new-ID modes.
 for _,merge in ipairs({true,false})do
  local actor,bench,dest=session();dest.merge=merge
  local chest=inventory({item('cloth',99,1)})
  local tx=assert(crafting.stage(actor,bench,recipe({{Item='cloth',Quantity=2}}),1,{chest},log))
  assert(actor.calls==2 and count(chest,'cloth')==97 and count(dest,'cloth')==2)
  dest.items={};assert(crafting.restore(tx,log));assert(count(chest,'cloth')==97)
 end
 -- Advanced Components: all six units, three classes, two storage inventories.
 local actor,bench,dest=session()
 local chest=inventory({item('component',10,2),item('plastic',8,3)})
 local fridge=inventory({item('foil',4,4)})
 local advanced=recipe({{Item='component',Quantity=3},{Item='plastic',Quantity=2},{Item='foil',Quantity=1}})
 local tx=assert(crafting.stage(actor,bench,advanced,1,{chest,fridge},log))
 assert(actor.calls==6 and count(dest,'component')==3 and count(dest,'plastic')==2 and count(dest,'foil')==1)
 assert(count(chest,'component')==7 and count(chest,'plastic')==6 and count(fridge,'foil')==3)
 -- Native rejection: return every staged unit to its original storage.
 assert(crafting.restore(tx,log));assert(#dest.items==0)
 assert(count(chest,'component')==10 and count(chest,'plastic')==8 and count(fridge,'foil')==4)
 -- Rejection partway through staging restores earlier successful transfers.
 actor.rejectKind='plastic';assert(not crafting.stage(actor,bench,advanced,1,{chest,fridge},log))
 assert(#dest.items==0 and count(chest,'component')==10 and count(chest,'plastic')==8 and count(fridge,'foil')==4)
 -- Existing workbench supply is preserved if the native craft is rejected.
 actor,bench,dest=session({item('cloth',1,5)});chest=inventory({item('cloth',3,6)})
 tx=assert(crafting.stage(actor,bench,recipe({{Item='cloth',Quantity=2}}),1,{chest},log))
 assert(actor.calls==1 and count(dest,'cloth')==2 and count(chest,'cloth')==2)
 assert(crafting.restore(tx,log));assert(count(dest,'cloth')==1 and count(chest,'cloth')==3)
 -- Split across chests and requested craft quantity greater than one.
 actor,bench,dest=session();chest=inventory({item('cloth',1,7)});fridge=inventory({item('cloth',3,8)})
 tx=assert(crafting.stage(actor,bench,recipe({{Item='cloth',Quantity=2}}),2,{chest,fridge},log))
 assert(actor.calls==4 and count(dest,'cloth')==4 and count(chest,'cloth')==0 and count(fridge,'cloth')==0)
 assert(crafting.restore(tx,log));assert(count(chest,'cloth')==1 and count(fridge,'cloth')==3)
 -- TagWithQuantity wrappers throw on properties belonging to ItemWithQuantity.
 actor,bench,dest=session();chest=inventory({item('cloth',2,9)})
 local tag=setmetatable({Tag='cloth',Quantity=2},{__index=function(_,key)error('Missing tag field: '..key)end})
 tx=assert(crafting.stage(actor,bench,recipe({},array({tag})),1,{chest},log));assert(count(dest,'cloth')==2)
 assert(crafting.restore(tx,log));assert(count(chest,'cloth')==2)
 -- Insufficient materials perform no transfers.
 actor,bench,dest=session();chest=inventory({item('cloth',1,10)})
 assert(not crafting.stage(actor,bench,recipe({{Item='cloth',Quantity=2}}),1,{chest},log));assert(actor.calls==0 and count(chest,'cloth')==1)
 -- Recipe availability reuses queries only within one refresh. Craft clicks
 -- use a fresh plan and must see changed storage contents.
 actor,bench,dest=session();chest=inventory({item('cloth',4,30)})
 local originalQuery=chest.GetItemsOfClass;local queryCount=0
 chest.GetItemsOfClass=function(self,...)queryCount=queryCount+1;return originalQuery(self,...)end
 local cachedLookup=crafting.cached_matches();local cachedRecipe=recipe({{Item='cloth',Quantity=2}})
 assert(crafting.plan(actor,bench,cachedRecipe,1,{chest},cachedLookup))
 assert(crafting.plan(actor,bench,cachedRecipe,1,{chest},cachedLookup))
 assert(queryCount==1,'Availability repeated the same storage query')
 chest.items={}
 assert(not crafting.plan(actor,bench,cachedRecipe,1,{chest}),'Craft click reused stale availability materials')
 assert(queryCount==2)
 return true
end
