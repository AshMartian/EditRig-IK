local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part; local bone=Instance.new('Bone'); bone.Parent=part
local definition=Instance.new('Folder'); definition.Parent=model; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1)
for _,entry in ipairs({{'Hinge',motor,'Hinge'},{'Ball',bone,'Ball'}}) do
 local ref=Instance.new('ObjectValue'); ref.Name=entry[1]; ref.Value=entry[2]; ref.Parent=definition
 ref:SetAttribute('Kind',entry[3]); ref:SetAttribute('Axis','Y'); ref:SetAttribute('LowerDegrees',-45); ref:SetAttribute('UpperDegrees',45); ref:SetAttribute('SwingDegrees',30)
 ref:SetAttribute('Control',entry[1]); ref:SetAttribute('Frequency',4)
end
local components={Actor=Actor,JointDrive=JointDrive,BallDrive={new=function(o) return BallDrive.new(o,Limits) end},JointAdapter={new=function(b,o) return JointAdapter.new(b,o,Limits) end}}
local actor=ActorRig.new(definition,components,{baseMode='animated',limitMode='absolute'})
local base=CFrame.new(.2,.3,.4)*CFrame.Angles(0,math.rad(70),0); motor.Transform=base; bone.Transform=base
actor:step(.01)
local expected=CFrame.new(.2,.3,.4)*CFrame.Angles(0,math.rad(45),0)
assert(motor.Transform:FuzzyEq(expected,1e-5) and bone.Transform:FuzzyEq(expected,1e-5),'combined animated pose must obey twist limits and preserve translation')
actor:step(.01)
assert(motor.Transform:FuzzyEq(expected,1e-5) and bone.Transform:FuzzyEq(expected,1e-5),'absolute limit must not accumulate')
local swingBase=CFrame.new(.2,.3,.4)*CFrame.Angles(math.rad(60),0,0); bone.Transform=swingBase
actor:step(.01)
assert(bone.Transform:FuzzyEq(CFrame.new(.2,.3,.4)*CFrame.Angles(math.rad(30),0,0),1e-5),'ball swing must be limited')
assert(#actor:destroy()==0 and motor.Transform:FuzzyEq(base,1e-5) and bone.Transform:FuzzyEq(swingBase,1e-5),'stop must restore latest animated bases')
assert(not pcall(function() ActorRig.new(definition,components,{limitMode='wrong'}) end),'unknown limit mode must fail')
model:Destroy()
return 'Absolute overlay limits constrain hinge and ball transforms and preserve translation'
