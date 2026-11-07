--!strict
-- Resolve one unambiguous directed path and snapshot authored joint metadata.
local ChainBuilder={}
function ChainBuilder.new(Config)
 local api={}
 function api.create(model,first,last,endpoint,name,options)
  options=options or {iterations=30,tolerance=0.01}
  assert(type(options)=='table' and type(options.iterations)=='number' and options.iterations%1==0 and options.iterations>=1 and options.iterations<=1000,'iterations must be an integer from 1 to 1000')
  assert(type(options.tolerance)=='number' and options.tolerance==options.tolerance and options.tolerance>=0 and options.tolerance<math.huge,'tolerance must be finite and nonnegative')
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
