local model=Instance.new('Model')
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Jaw'; motor.Parent=part
local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=part
local function settings(joint,axis)
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge')
 joint:SetAttribute('EditRigIK_Axis',axis); joint:SetAttribute('EditRigIK_LowerDegrees',-30)
 joint:SetAttribute('EditRigIK_UpperDegrees',90); joint:SetAttribute('EditRigIK_SwingDegrees',0)
end
settings(motor,'Y'); settings(bone,'Z')
motor:SetAttribute('EditRigIK_Control','Action'); bone:SetAttribute('EditRigIK_Control','Action')
motor:SetAttribute('EditRigIK_Impulse','Kick'); bone:SetAttribute('EditRigIK_Impulse','Kick')
motor:SetAttribute('EditRigIK_Frequency',8); bone:SetAttribute('EditRigIK_Frequency',8)
local definition=DefinitionBuilder.new(Config).create(model); definition.Parent=model
local actor=ActorRig.new(definition,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
actor:setControl('Action',1); actor:step(1/60)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,math.pi/2,0),1e-5))
assert(bone.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5))
actor:setControl('Action',0); actor:impulse('Kick',1); actor:step(0.1)
assert(not motor.Transform:FuzzyEq(CFrame.identity,1e-5) and not bone.Transform:FuzzyEq(CFrame.identity,1e-5),'shared impulse must drive both joints')
assert(#actor:destroy()==0)
model:Destroy()
return 'Authored metadata to direct-control actor integration passed'
