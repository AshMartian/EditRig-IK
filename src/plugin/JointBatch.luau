--!strict
-- Validate every selected joint and setting before writing metadata.
local JointBatch={}
function JointBatch.prepare(joints,settings,config,keys)
 assert(type(joints)=='table' and #joints>=2 and #joints<=128,'select 2–128 joints')
 assert(type(settings)=='table' and type(config)=='table' and type(keys)=='table','settings and validators required')
 local limit=config.validate(settings)
 assert(type(settings.frequency)=='number','enter a damping frequency')
 local holdKey=keys.validateKey(settings.holdKey)
 local impulseKey=keys.validateKey(settings.impulseKey)
 local holdValue=keys.validateAmount(limit.kind,'Hold',settings.holdValue)
 local impulseValue=keys.validateAmount(limit.kind,'Impulse',settings.impulseValue)
 local entries,seen={},{}
 for _,joint in ipairs(joints) do
  assert(typeof(joint)=='Instance' and (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint.Parent and not seen[joint],'selection must contain distinct parented Motor6Ds or Bones')
  local drive=config.validateDrive(settings,joint.Name)
  table.insert(entries,{joint=joint,parent=joint.Parent,limit=limit,drive=drive,holdKey=holdKey,impulseKey=impulseKey,holdValue=holdValue,impulseValue=impulseValue})
  seen[joint]=true
 end
 return entries
end
function JointBatch.apply(entries)
 assert(type(entries)=='table' and #entries>=2,'prepared joint settings required')
 for _,entry in ipairs(entries) do assert(entry.joint.Parent==entry.parent,'joint selection changed; prepare again') end
 for _,entry in ipairs(entries) do
  local joint,limit,drive=entry.joint,entry.limit,entry.drive
  joint:SetAttribute('EditRigIK_Kind',limit.kind); joint:SetAttribute('EditRigIK_Axis',limit.axis)
  joint:SetAttribute('EditRigIK_LowerDegrees',limit.lower); joint:SetAttribute('EditRigIK_UpperDegrees',limit.upper); joint:SetAttribute('EditRigIK_SwingDegrees',limit.swing); joint:SetAttribute('EditRigIK_Weight',limit.weight)
  joint:SetAttribute('EditRigIK_Control',drive.control); joint:SetAttribute('EditRigIK_Impulse',drive.impulse); joint:SetAttribute('EditRigIK_Frequency',drive.frequency)
  joint:SetAttribute('EditRigIK_HoldKey',entry.holdKey); joint:SetAttribute('EditRigIK_ImpulseKey',entry.impulseKey)
  joint:SetAttribute('EditRigIK_HoldValue',entry.holdValue); joint:SetAttribute('EditRigIK_ImpulseValue',entry.impulseValue)
  joint:SetAttribute('EditRigIK_SchemaVersion',1)
 end
end
return JointBatch
