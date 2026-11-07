local model=Instance.new('Model')
local folder=Instance.new('Folder'); folder.Name='EditRigIKActor'; folder.Parent=model
folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local builder=DefinitionBuilder.new(Config)
local defaults=builder.readActorOptions(folder)
assert(defaults.baseMode=='fixed' and defaults.limitMode=='offset','legacy definitions must use safe defaults')
assert(not pcall(builder.writeActorOptions,folder,{baseMode='animated',limitMode='invalid'}),'invalid option must fail')
assert(folder:GetAttribute('EditRigIK_BaseMode')==nil and folder:GetAttribute('EditRigIK_LimitMode')==nil,'invalid input must not partially write')
builder.writeActorOptions(folder,{baseMode='animated',limitMode='absolute'})
local saved=builder.readActorOptions(folder)
assert(saved.baseMode=='animated' and saved.limitMode=='absolute','saved modes must round trip')
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part
local ref=Instance.new('ObjectValue'); ref.Name='Jaw'; ref.Value=motor; ref.Parent=folder
ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Y'); ref:SetAttribute('LowerDegrees',-45); ref:SetAttribute('UpperDegrees',45)
ref:SetAttribute('Control','Jaw'); ref:SetAttribute('Frequency',4)
local components={Actor=Actor,JointDrive=JointDrive,JointAdapter={new=function(b,o) return JointAdapter.new(b,o,Limits) end}}
local actor=ActorRig.new(folder,components)
local base=CFrame.Angles(0,math.rad(70),0); motor.Transform=base
actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,math.rad(45),0),1e-5),'saved absolute mode must constrain animated base')
assert(#actor:destroy()==0 and motor.Transform:FuzzyEq(base,1e-5),'actor must restore animated base')
folder:SetAttribute('EditRigIK_BaseMode','invalid')
assert(not pcall(ActorRig.new,folder,components),'invalid saved mode must fail')
local overridden=ActorRig.new(folder,components,{baseMode='fixed',limitMode='offset'}); overridden:destroy()
model:Destroy()
return 'Actor options validate, round trip, and control runtime behavior'
