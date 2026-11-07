--!strict
-- Resolve one unambiguous directed path and snapshot authored joint metadata.
local ChainBuilder={}
function ChainBuilder.new(Config)
 local api={}
 function api.validateSettings(options)
  assert(type(options)=='table' and type(options.iterations)=='number' and options.iterations%1==0 and options.iterations>=1 and options.iterations<=1000,'iterations must be an integer from 1 to 1000')
  assert(type(options.tolerance)=='number' and options.tolerance==options.tolerance and options.tolerance>=0 and options.tolerance<math.huge,'tolerance must be finite and nonnegative')
  local maxStepDegrees=if options.maxStepDegrees==nil then 180 else options.maxStepDegrees
  assert(type(maxStepDegrees)=='number' and maxStepDegrees==maxStepDegrees and maxStepDegrees>0 and maxStepDegrees<=180,'maximum correction must be greater than 0 and at most 180 degrees')
  return {iterations=options.iterations,tolerance=options.tolerance,maxStepDegrees=maxStepDegrees}
 end
 local function checkDefinition(definition)
  assert(typeof(definition)=='Instance' and definition:IsA('Folder') and definition:GetAttribute('SchemaVersion')==1,'select a supported chain definition')
  local parent=definition.Parent
  assert(parent and parent:IsA('Folder') and parent.Name=='EditRigIKChains' and parent.Parent and parent.Parent:IsA('Model'),'chain must belong to a model EditRigIKChains folder')
  assert(definition:FindFirstChild('Joints') and definition:FindFirstChild('Endpoint'),'chain references missing')
 end
 function api.readSettings(definition)
  checkDefinition(definition)
  return api.validateSettings({iterations=definition:GetAttribute('Iterations'),tolerance=definition:GetAttribute('Tolerance'),maxStepDegrees=definition:GetAttribute('MaxStepDegrees')})
 end
 function api.writeSettings(definition,options)
  checkDefinition(definition)
  local settings=api.validateSettings(options)
  definition:SetAttribute('Iterations',settings.iterations)
  definition:SetAttribute('Tolerance',settings.tolerance)
  definition:SetAttribute('MaxStepDegrees',settings.maxStepDegrees)
 end
 function api.prepareLimitRefresh(definition)
  checkDefinition(definition)
  local model=definition.Parent.Parent
  local list=definition:FindFirstChild('Joints')
  local endpoint=definition:FindFirstChild('Endpoint')
  assert(list:IsA('Folder') and endpoint:IsA('ObjectValue') and endpoint.Value and endpoint.Value.ClassName=='Attachment' and endpoint.Value:IsDescendantOf(model),'invalid chain references')
  local refs=list:GetChildren()
  assert(#refs>0 and #refs<=128,'invalid joint count')
  for _,ref in ipairs(refs) do
   local order=ref:GetAttribute('Order')
   assert(ref:IsA('ObjectValue') and type(order)=='number' and order==order and math.abs(order)<math.huge,'invalid joint reference')
  end
  table.sort(refs,function(a,b) return a:GetAttribute('Order')<b:GetAttribute('Order') end)
  local entries,seen,parts={},{},{}
  local previous,kind=nil,nil
  for i,ref in ipairs(refs) do
   local joint=ref.Value
   assert(ref:GetAttribute('Order')==i and joint and joint:IsDescendantOf(model) and (joint:IsA('Motor6D') or joint:IsA('Bone')) and not seen[joint],'invalid joint order or reference')
   if not kind then kind=joint.ClassName end
   assert(joint.ClassName==kind,'mixed joint types are unsupported')
   if kind=='Motor6D' then
    assert(joint.Enabled and joint.Part0 and joint.Part1 and joint.Part0~=joint.Part1,'invalid motor connection')
    if previous then assert(previous.Part1==joint.Part0,'disconnected motor chain') end
    if not previous then parts[joint.Part0]=true end
    assert(not parts[joint.Part1],'cyclic motor chain')
    parts[joint.Part1]=true
   elseif previous then assert(joint.Parent==previous,'disconnected Bone chain') end
   assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'save limit settings on every joint: '..joint.Name)
   local config=Config.validate({kind=joint:GetAttribute('EditRigIK_Kind'),axis=joint:GetAttribute('EditRigIK_Axis'),lower=joint:GetAttribute('EditRigIK_LowerDegrees'),upper=joint:GetAttribute('EditRigIK_UpperDegrees'),swing=joint:GetAttribute('EditRigIK_SwingDegrees')})
   table.insert(entries,{ref=ref,config=config}); seen[joint]=true; previous=joint
  end
  assert(endpoint.Value.Parent==(if kind=='Motor6D' then previous.Part1 else previous),'endpoint parent does not match chain')
  return entries
 end
 function api.refreshLimits(definition)
  local entries=api.prepareLimitRefresh(definition)
  for _,entry in ipairs(entries) do
   local ref,config=entry.ref,entry.config
   ref:SetAttribute('Kind',config.kind); ref:SetAttribute('Axis',config.axis)
   ref:SetAttribute('LowerDegrees',config.lower); ref:SetAttribute('UpperDegrees',config.upper); ref:SetAttribute('SwingDegrees',config.swing)
  end
 end
 function api.create(model,first,last,endpoint,name,options)
  options=api.validateSettings(options or {iterations=30,tolerance=0.01})
  assert(typeof(model)=='Instance' and model:IsA('Model'),'actor model required')
  assert(type(name)=='string' and #name>0 and #name<=64,'chain name must be 1–64 characters')
  assert(typeof(first)=='Instance' and typeof(last)=='Instance' and first:IsDescendantOf(model) and last:IsDescendantOf(model),'joints must belong to the selected model')
  assert((first:IsA('Motor6D') and last:IsA('Motor6D')) or (first:IsA('Bone') and last:IsA('Bone')),'root and end must both be Motor6Ds or both Bones')
  assert(typeof(endpoint)=='Instance' and endpoint.ClassName=='Attachment' and endpoint:IsDescendantOf(model),'select a regular endpoint Attachment')
  local paths={}
  if first:IsA('Bone') then
   local path={}; local current=last
   while current and current:IsA('Bone') do
    table.insert(path,1,current)
    if current==first then table.insert(paths,path); break end
    assert(#path<=128,'chain too long'); current=current.Parent
   end
  else
   local nextByPart={}
   for _,candidate in ipairs(model:GetDescendants()) do
    if candidate:IsA('Motor6D') and candidate.Part0 and candidate.Part1 then
     local list=nextByPart[candidate.Part0] or {}; table.insert(list,candidate); nextByPart[candidate.Part0]=list
    end
   end
   local explored=0
   local function visit(joint,path,visited)
    explored+=1; assert(explored<=10000 and #path<=128,'chain search exceeded safety limit')
    if visited[joint] then return end
    visited[joint]=true; table.insert(path,joint)
    if joint==last then table.insert(paths,table.clone(path))
    elseif joint.Part1 then
     for _,nextJoint in ipairs(nextByPart[joint.Part1] or {}) do
      if #paths>1 then break end
      visit(nextJoint,path,visited)
     end
    end
    table.remove(path); visited[joint]=nil
   end
   visit(first,{}, {})
  end
  assert(#paths==1, if #paths==0 then 'no directed path connects those joints' else 'multiple paths connect those joints')
  local path=paths[1]
  if first:IsA('Motor6D') then
   assert(first.Part0 and first.Part1,'root motor must connect two parts')
   local parts={[first.Part0]=true}
   for _,joint in ipairs(path) do
    assert(joint.Enabled and joint.Part0 and joint.Part1 and not parts[joint.Part1],'invalid or cyclic motor chain')
    parts[joint.Part1]=true
   end
  end
  assert(endpoint.Parent==(if last:IsA('Motor6D') then last.Part1 else last),'endpoint must be a direct child of the final part or Bone')
  local entries={}
  for _,joint in ipairs(path) do
   assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'save limit settings on every joint: '..joint.Name)
   local config=Config.validate({kind=joint:GetAttribute('EditRigIK_Kind'),axis=joint:GetAttribute('EditRigIK_Axis'),lower=joint:GetAttribute('EditRigIK_LowerDegrees'),upper=joint:GetAttribute('EditRigIK_UpperDegrees'),swing=joint:GetAttribute('EditRigIK_SwingDegrees')})
   table.insert(entries,{joint=joint,config=config})
  end
  local folder=Instance.new('Folder'); folder.Name=name; folder:SetAttribute('SchemaVersion',1)
  folder:SetAttribute('Iterations',options.iterations); folder:SetAttribute('Tolerance',options.tolerance)
  folder:SetAttribute('MaxStepDegrees',options.maxStepDegrees)
  local endpointRef=Instance.new('ObjectValue'); endpointRef.Name='Endpoint'; endpointRef.Value=endpoint; endpointRef.Parent=folder
  local list=Instance.new('Folder'); list.Name='Joints'; list.Parent=folder
  for i,e in ipairs(entries) do
   local ref=Instance.new('ObjectValue'); ref.Name=string.format('Joint%03d',i); ref.Value=e.joint
   ref:SetAttribute('Order',i); ref:SetAttribute('Kind',e.config.kind); ref:SetAttribute('Axis',e.config.axis)
   ref:SetAttribute('LowerDegrees',e.config.lower); ref:SetAttribute('UpperDegrees',e.config.upper); ref:SetAttribute('SwingDegrees',e.config.swing)
   ref.Parent=list
  end
  return folder
 end
 return api
end
return ChainBuilder
