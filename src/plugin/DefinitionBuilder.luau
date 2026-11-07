--!strict
-- Build an unparented direct-control actor definition from authored joint metadata.
local DefinitionBuilder={}
function DefinitionBuilder.new(Config)
 local api={}
 local function readJoint(joint)
  assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'unsupported or missing joint metadata: '..joint.Name)
  local config=Config.validate({kind=joint:GetAttribute('EditRigIK_Kind'),axis=joint:GetAttribute('EditRigIK_Axis'),lower=joint:GetAttribute('EditRigIK_LowerDegrees'),upper=joint:GetAttribute('EditRigIK_UpperDegrees'),swing=joint:GetAttribute('EditRigIK_SwingDegrees')})
  assert(config.kind=='Hinge','direct-control actor currently supports hinge limits only: '..joint.Name)
  assert(config.lower<=0 and config.upper>=0,'hinge limits must include zero: '..joint.Name)
  local drive=Config.validateDrive({control=joint:GetAttribute('EditRigIK_Control'),impulse=joint:GetAttribute('EditRigIK_Impulse'),frequency=joint:GetAttribute('EditRigIK_Frequency')},joint.Name)
  return config,drive
 end
 local function writeRef(ref,config,drive)
  ref:SetAttribute('Kind',config.kind); ref:SetAttribute('Axis',config.axis)
  ref:SetAttribute('LowerDegrees',config.lower); ref:SetAttribute('UpperDegrees',config.upper)
  ref:SetAttribute('Control',drive.control); ref:SetAttribute('Impulse',drive.impulse); ref:SetAttribute('Frequency',drive.frequency)
 end
 function api.prepareRefresh(folder)
  assert(typeof(folder)=='Instance' and folder:IsA('Folder') and folder.Name=='EditRigIKActor' and folder:GetAttribute('EditRigIK_ActorSchemaVersion')==1 and folder.Parent and folder.Parent:IsA('Model'),'select a supported actor definition')
  local refs=folder:GetChildren(); assert(#refs>0,'actor has no joint bindings')
  local entries,seenNames,seenJoints={},{},{}
  for _,ref in ipairs(refs) do
   local joint=if ref:IsA('ObjectValue') then ref.Value else nil
   assert(joint and (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint:IsDescendantOf(folder.Parent),'invalid actor joint reference')
   assert(ref.Name~='' and not seenNames[ref.Name] and not seenJoints[joint],'duplicate actor binding')
   local config,drive=readJoint(joint)
   table.insert(entries,{ref=ref,config=config,drive=drive})
   seenNames[ref.Name]=true; seenJoints[joint]=true
  end
  return entries
 end
 function api.refresh(folder)
  local entries=api.prepareRefresh(folder)
  for _,entry in ipairs(entries) do writeRef(entry.ref,entry.config,entry.drive) end
 end
 function api.create(model)
  assert(typeof(model)=='Instance' and model:IsA('Model'),'select one model')
  local entries,seen={},{}
  for _,joint in ipairs(model:GetDescendants()) do
   if (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint:GetAttribute('EditRigIK_SchemaVersion')~=nil then
    assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'unsupported joint metadata schema: '..joint.Name)
    assert(joint.Name~='' and not seen[joint.Name],'configured joint names must be unique: '..joint.Name)
    seen[joint.Name]=true
    local config,drive=readJoint(joint)
    table.insert(entries,{joint=joint,config=config,drive=drive})
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
   writeRef(ref,entry.config,entry.drive); ref.Parent=folder
  end
  return folder
 end
 return api
end
return DefinitionBuilder
