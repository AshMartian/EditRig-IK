-- Unparented fixtures. ActorRig consumes saved per-joint metadata via ObjectValues.
local model=Instance.new('Model')
local motor=Instance.new('Motor6D'); motor.Name='Jaw'; motor.Parent=model
local part=Instance.new('Part'); part.Parent=model
local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=part
local definitions=Instance.new('Folder'); definitions.Name='ActorDefinition'; definitions.Parent=model; definitions:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local function define(name,joint,axis)
 local ref=Instance.new('ObjectValue'); ref.Name=name; ref.Value=joint
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis',axis)
 ref:SetAttribute('LowerDegrees',-45); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control',name); ref:SetAttribute('Impulse',name..'Impulse'); ref:SetAttribute('Frequency',4)
 ref.Parent=definitions
end
define('Jaw',motor,'Y'); define('Tail',bone,'Z')
definitions:SetAttribute('EditRigIK_ActorSchemaVersion',2)
assert(not pcall(function() ActorRig.new(definitions,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter}) end), 'unsupported schema must be rejected')
definitions:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local actor=ActorRig.new(definitions,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
actor:setControl('Jaw',0.5); actor:setControl('Tail',-1)
actor:step(0.1)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,math.rad(45),0),1e-5))
assert(bone.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(-45)),1e-5))
actor:impulse('JawImpulse',1); actor:step(0.1)
assert(#actor:destroy()==0)
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5) and bone.Transform:FuzzyEq(CFrame.identity,1e-5))
model:Destroy()
return 'ActorRig configured Motor6D and Bone control passed'
