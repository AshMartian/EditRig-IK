local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local hinge=Instance.new('Motor6D'); hinge.Name='Jaw'; hinge.Parent=part
local ball=Instance.new('Bone'); ball.Name='Shoulder'; ball.Parent=part
local function configure(joint,kind,control,impulse)
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind',kind); joint:SetAttribute('EditRigIK_Axis','Y')
 joint:SetAttribute('EditRigIK_LowerDegrees',-45); joint:SetAttribute('EditRigIK_UpperDegrees',45); joint:SetAttribute('EditRigIK_SwingDegrees',30)
 joint:SetAttribute('EditRigIK_Control',control); joint:SetAttribute('EditRigIK_Impulse',impulse); joint:SetAttribute('EditRigIK_Frequency',4)
end
configure(hinge,'Hinge','Bite','Snap'); configure(ball,'Ball','Aim','Nudge')
local builder=DefinitionBuilder.new(Config); local definition=builder.create(model); definition.Parent=model
assert(definition.Shoulder:GetAttribute('Kind')=='Ball' and definition.Shoulder:GetAttribute('SwingDegrees')==30,'ball configuration must persist')
local components={Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter,BallDrive={new=function(options) return BallDrive.new(options,Limits) end}}
local actor=ActorRig.new(definition,components)
actor:setControl('Bite',1); actor:setControl('Aim',{math.pi/2,0,0})
local result=actor:step(.01)
assert(hinge.Transform:FuzzyEq(CFrame.Angles(0,math.pi/4,0),1e-5),'hinge must receive scalar control')
assert(ball.Transform:FuzzyEq(CFrame.Angles(math.pi/6,0,0),1e-5),'ball must respect swing limit')
assert(type(result.Jaw)=='number' and type(result.Shoulder)=='table','actor returns both output kinds')
assert(not pcall(function() actor:setControl('Aim',1) end) and not pcall(function() actor:impulse('Nudge',1) end),'ball routes must require vectors')
assert(not pcall(function() actor:setControl('Bite',{1,0,0}) end),'hinge route must require scalar')
actor:clearControl('Aim')
local context=Instance.new('InputContext'); local action=Instance.new('InputAction'); action.Type=Enum.InputActionType.Bool; action.Parent=context
local key=Instance.new('InputBinding'); key.Type=Enum.InputBindingType.Scriptable; key.Parent=action
local inputs=InputBindings.new(actor); inputs:bindImpulse(action,'Nudge',{0,1,0})
key:Fire(true); task.wait(); actor:step(.1)
assert(not ball.Transform:FuzzyEq(CFrame.identity,1e-5),'ball vector impulse should move the joint')
inputs:destroy(); context:Destroy()
assert(#actor:destroy()==0 and hinge.Transform:FuzzyEq(CFrame.identity,1e-5) and ball.Transform:FuzzyEq(CFrame.identity,1e-5),'destroy should restore both kinds')
ball:SetAttribute('EditRigIK_Control','Bite')
assert(not pcall(function() builder.create(model) end),'mixed scalar/vector control name must be rejected')
configure(hinge,'Ball','MotorBall','MotorNudge'); configure(ball,'Hinge','BoneHinge','BoneSnap')
local swapped=builder.create(model); swapped.Parent=model
local second=ActorRig.new(swapped,components)
second:setControl('MotorBall',{math.pi/2,0,0}); second:setControl('BoneHinge',1); second:step(.01)
assert(hinge.Transform:FuzzyEq(CFrame.Angles(math.pi/6,0,0),1e-5),'Motor6D ball control must respect swing limit')
assert(ball.Transform:FuzzyEq(CFrame.Angles(0,math.pi/4,0),1e-5),'Bone hinge control must work')
second:destroy(); swapped:Destroy()
local adapter=JointAdapter.new({{name='A',joint=hinge,axis=Vector3.yAxis},{name='B',joint=ball,axis=Vector3.yAxis,kind='Ball'}},{exclusive=true})
assert(not pcall(function() adapter:apply({A=.5,B={0,0,0,0}}) end),'invalid ball rotation must reject the complete update')
assert(hinge.Transform:FuzzyEq(CFrame.identity,1e-5) and ball.Transform:FuzzyEq(CFrame.identity,1e-5),'invalid ball rotation must not partially write hinge')
adapter:destroy()
model:Destroy()
return 'Authored mixed hinge and ball actor controls Motor6D and Bone'
