--!strict
-- Conservative lifetime guard for the docked preview's source snapshot.
local PreviewGuard={}
function PreviewGuard.new(source,definition,selection,runService,onInvalidate)
 assert(typeof(source)=='Instance' and source:IsA('Model') and definition:IsDescendantOf(source),'preview source required')
 assert(type(onInvalidate)=='function','invalidation callback required')
 local selected=selection:Get()
 assert(#selected==1 and selected[1]==definition and runService:IsEdit(),'preview requires the selected chain in Edit mode')
 local originalParent=source.Parent
 local connections={}
 local dead=false
 local function close()
  if dead then return end; dead=true
  for _,connection in ipairs(connections) do connection:Disconnect() end
  table.clear(connections)
 end
 local function invalidate(reason)
  if dead then return end
  close(); onInvalidate(reason)
 end
 local function watch(item)
  table.insert(connections,item.Changed:Connect(function() invalidate('source changed') end))
  table.insert(connections,item.AttributeChanged:Connect(function() invalidate('source changed') end))
 end
 local ok,err=pcall(function()
  watch(source)
  for _,item in ipairs(source:GetDescendants()) do watch(item) end
  table.insert(connections,source.DescendantAdded:Connect(function() invalidate('source changed') end))
  table.insert(connections,source.DescendantRemoving:Connect(function() invalidate('source changed') end))
  table.insert(connections,source.AncestryChanged:Connect(function() invalidate('source changed') end))
  table.insert(connections,selection.SelectionChanged:Connect(function()
   local items=selection:Get()
   if #items~=1 or items[1]~=definition then invalidate('selection changed') end
  end))
  table.insert(connections,runService:GetPropertyChangedSignal('RunState'):Connect(function()
   if not runService:IsEdit() then invalidate('left Edit mode') end
  end))
 end)
 if not ok then close(); error(err) end
 local function check()
  if dead then return false end
  local items=selection:Get()
  if not runService:IsEdit() then invalidate('left Edit mode')
  elseif #items~=1 or items[1]~=definition then invalidate('selection changed')
  elseif source.Parent~=originalParent or not definition:IsDescendantOf(source) then invalidate('source changed') end
  return not dead
 end
 return {destroy=function() close() end,check=function() return check() end}
end
return PreviewGuard
