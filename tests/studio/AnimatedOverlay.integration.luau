local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part; local bone=Instance.new('Bone'); bone.Parent=part
local definition=Instance.new('Folder'); definition.Parent=model; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1)
for _,entry in ipairs({{'Motor',motor},{'Bone',bone}}) do
 local ref=Instance.new('ObjectValue'); ref.Name=entry[1]; ref.Value=entry[2]; ref.Parent=definition
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control','Move'); ref:SetAttribute('Frequency',4)
end
local components={Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter}
local actor=ActorRig.new(definition,components,{baseMode='animated'}); actor:setControl('Move',.5)
local base1=CFrame.Angles(.2,0,0); motor.Transform=base1; bone.Transform=base1
actor:step(.01); local expected1=base1*CFrame.Angles(0,0,math.pi/4)
assert(motor.Transform:FuzzyEq(expected1,1e-5) and bone.Transform:FuzzyEq(expected1,1e-5),'overlay should use animated base')
actor:step(.01)
assert(motor.Transform:FuzzyEq(expected1,1e-5) and bone.Transform:FuzzyEq(expected1,1e-5),'overlay must not accumulate when base is unchanged')
local base2=CFrame.Angles(0,.3,0); motor.Transform=base2; bone.Transform=base2
actor:step(.01); local expected2=base2*CFrame.Angles(0,0,math.pi/4)
assert(motor.Transform:FuzzyEq(expected2,1e-5) and bone.Transform:FuzzyEq(expected2,1e-5),'updated animated base must be used')
assert(#actor:destroy()==0 and motor.Transform:FuzzyEq(base2,1e-5) and bone.Transform:FuzzyEq(base2,1e-5),'destroy should restore last animated base')
assert(not pcall(function() ActorRig.new(definition,components,{baseMode='bad'}) end),'unknown base mode must be rejected')
local adapter=JointAdapter.new({{name='Motor',joint=motor,axis=Vector3.xAxis,kind='Ball'},{name='Bone',joint=bone,axis=Vector3.xAxis,kind='Ball'}},{exclusive=true,baseMode='animated'})
local q={math.sin(.2),0,0,math.cos(.2)}
adapter:apply({Motor=q,Bone=q}); adapter:apply({Motor=q,Bone=q})
assert(motor.Transform:FuzzyEq(base2*CFrame.Angles(.4,0,0),1e-5) and bone.Transform:FuzzyEq(base2*CFrame.Angles(.4,0,0),1e-5),'ball overlays must not accumulate')
local external=CFrame.Angles(.6,0,0); bone.Transform=external
local conflicts=adapter:destroy()
assert(#conflicts==1 and conflicts[1]=='Bone' and bone.Transform:FuzzyEq(external,1e-5),'cleanup must preserve later external changes')
assert(motor.Transform:FuzzyEq(base2,1e-5),'cleanup restores uncontested animated base')
model:Destroy()
return 'Animated overlay uses fresh bases without accumulation on Motor6D and Bone'
