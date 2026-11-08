--!strict
-- Read-only, bounded model-wide guides for valid saved limits only.
local SavedLimitOverlay={}
function SavedLimitOverlay.new(rig,holder,config,gizmo,geometry,maxVisible)
 assert(typeof(rig)=='Instance' and rig:IsA('Model') and typeof(holder)=='Instance','rig and guide holder required')
 assert(type(maxVisible)=='number' and maxVisible%1==0 and maxVisible>=1 and maxVisible<=24,'invalid guide cap')
 local dirty=true
 local dead=false
 local entries,watchers={},{}
 local connections={}
 local function clearEntries()
  for _,entry in ipairs(entries) do entry.guide:destroy() end
  entries={}
  for _,watcher in ipairs(watchers) do watcher:Disconnect() end
  watchers={}
 end
 local eligible=0
 local function rebuild()
  clearEntries(); eligible=0
  for _,item in ipairs(rig:GetDescendants()) do
   if item:IsA('Motor6D') or item:IsA('Bone') then
    table.insert(watchers,item.AttributeChanged:Connect(function() dirty=true end))
    local input={kind=item:GetAttribute('EditRigIK_Kind'),axis=item:GetAttribute('EditRigIK_Axis'),lower=item:GetAttribute('EditRigIK_LowerDegrees'),upper=item:GetAttribute('EditRigIK_UpperDegrees'),swing=item:GetAttribute('EditRigIK_SwingDegrees'),weight=item:GetAttribute('EditRigIK_Weight')}
    local ok,valid=pcall(config.validate,input)
    if item:GetAttribute('EditRigIK_SchemaVersion')==1 and ok then
     eligible+=1
     if #entries<maxVisible then
      local guide=gizmo.new(holder,geometry,true)
      if guide:setLimits(valid) then table.insert(entries,{joint=item,guide=guide}) else guide:destroy() end
     end
    end
   end
  end
  dirty=false
 end
 table.insert(connections,rig.DescendantAdded:Connect(function() dirty=true end))
 table.insert(connections,rig.DescendantRemoving:Connect(function() dirty=true end))
 local api={}
 function api:update(selected)
  assert(not dead,'saved limit overlay is closed')
  if dirty then rebuild() end
  local shown=0
  local inspectingJoint=typeof(selected)=='Instance' and (selected:IsA('Motor6D') or selected:IsA('Bone'))
  for _,entry in ipairs(entries) do
   if inspectingJoint or not entry.joint:IsDescendantOf(rig) then entry.guide:clear()
   elseif entry.guide:update(entry.joint) then shown+=1 end
  end
  return shown,eligible
 end
 function api:destroy()
  if dead then return end; dead=true
  for _,connection in ipairs(connections) do connection:Disconnect() end
  clearEntries()
 end
 return api
end
return SavedLimitOverlay
