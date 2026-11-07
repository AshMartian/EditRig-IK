--!strict
-- Build an unparented direct-control actor definition from authored joint metadata.
local DefinitionBuilder={}
function DefinitionBuilder.new(Config)
 local api={}
 function api.create(model)
  assert(typeof(model)=='Instance' and model:IsA('Model'),'select one model')
  local entries,seen={},{}
  for _,joint in ipairs(model:GetDescendants()) do
   if (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint:GetAttribute('EditRigIK_SchemaVersion')~=nil then
    assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'unsupported joint metadata schema: '..joint.Name)
    assert(joint.Name~='' and not seen[joint.Name],'configured joint names must be unique: '..joint.Name)
    seen[joint.Name]=true
    local config=Config.validate({kind=joint:GetAttribute('EditRigIK_Kind'),axis=joint:GetAttribute('EditRigIK_Axis'),lower=joint:GetAttribute('EditRigIK_LowerDegrees'),upper=joint:GetAttribute('EditRigIK_UpperDegrees'),swing=joint:GetAttribute('EditRigIK_SwingDegrees')})
    assert(config.kind=='Hinge','direct-control actor currently supports hinge limits only: '..joint.Name)
    assert(config.lower<=0 and config.upper>=0,'hinge limits must include zero: '..joint.Name)
    table.insert(entries,{joint=joint,config=config})
   end
  end
  assert(#entries>0,'no configured joints found; save hinge settings on a Motor6D or Bone first')
  table.sort(entries,function(a,b) return a.joint.Name<b.joint.Name end)
  local folder=Instance.new('Folder')
  folder.Name='EditRigIKActor'
  folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
  for _,entry in ipairs(entries) do
   local ref=Instance.new('ObjectValue')
   ref.Name=entry.joint.Name; ref.Value=entry.joint
   ref:SetAttribute('Kind',entry.config.kind); ref:SetAttribute('Axis',entry.config.axis)
   ref:SetAttribute('LowerDegrees',entry.config.lower); ref:SetAttribute('UpperDegrees',entry.config.upper)
   ref:SetAttribute('Control',entry.joint.Name); ref:SetAttribute('Impulse',entry.joint.Name..'Impulse')
   ref:SetAttribute('Frequency',4); ref.Parent=folder
  end
  return folder
 end
 return api
end
return DefinitionBuilder
