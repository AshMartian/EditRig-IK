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
local definition=DefinitionBuilder.new(Config).create(model); definition.Parent=model
local actor=ActorRig.new(definition,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
actor:setControl('Jaw',1); actor:setControl('Tail',-1); actor:step(1/60)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,math.pi/2,0),1e-5))
assert(bone.Transform:FuzzyEq(CFrame.Angles(0,0,-math.pi/6),1e-5))
assert(#actor:destroy()==0)
model:Destroy()
return 'Authored metadata to direct-control actor integration passed'
