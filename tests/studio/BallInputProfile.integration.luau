local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local hinge=Instance.new('Motor6D'); hinge.Name='Jaw'; hinge.Parent=part
local ball=Instance.new('Bone'); ball.Name='Shoulder'; ball.Parent=part
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
local function add(name,joint,kind,axis,control,impulse,holdKey,impulseKey)
 joint:SetAttribute('EditRigIK_HoldKey',holdKey); joint:SetAttribute('EditRigIK_ImpulseKey',impulseKey)
 local ref=Instance.new('ObjectValue'); ref.Name=name; ref.Value=joint; ref.Parent=definition
 ref:SetAttribute('Kind',kind); ref:SetAttribute('Axis',axis); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('SwingDegrees',30); ref:SetAttribute('Control',control); ref:SetAttribute('Impulse',impulse); ref:SetAttribute('Frequency',4)
end
add('Jaw',hinge,'Hinge','Z','Bite','Snap','F','')
add('Shoulder',ball,'Ball','X','Aim','Nudge','E','Q')
local profile=InputProfileBuilder.create(definition); assert(not profile.Enabled)
local keys={}
for _,action in ipairs(profile:GetChildren()) do
 local control=action:GetAttribute('Control'); local route=action:GetAttribute('Route')
 if control=='Aim' or control=='Nudge' then assert(action:GetAttribute('Value')==Vector3.xAxis,'ball key should store axis vector') end
 for _,binding in ipairs(action:GetChildren()) do binding:Destroy() end
 local key=Instance.new('InputBinding'); key.Type=Enum.InputBindingType.Scriptable; key.Parent=action
 keys[route..control]=key
end
local components={Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter,BallDrive={new=function(options) return BallDrive.new(options,Limits) end}}
local actor=ActorRig.new(definition,components); local inputs=InputBindings.new(actor); local handle=inputs:bindProfile(profile)
profile.Enabled=true; keys.HoldBite:Fire(true); keys.HoldAim:Fire(true); task.wait(); actor:step(.01)
assert(hinge.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5),'hinge key must drive scalar control')
assert(ball.Transform:FuzzyEq(CFrame.Angles(1,0,0),1e-5),'ball key must drive the configured twist axis')
keys.HoldAim:Fire(false); task.wait(); actor:step(.01)
assert(ball.Transform:FuzzyEq(CFrame.identity,1e-5),'releasing ball key must reset vector control')
keys.ImpulseNudge:Fire(true); task.wait(); actor:step(.1)
assert(not ball.Transform:FuzzyEq(CFrame.identity,1e-5),'ball impulse key must trigger vector impulse')
handle:destroy(); actor:step(3)
assert(hinge.Transform:FuzzyEq(CFrame.identity,1e-5),'profile cleanup must release an active scalar hold')
local directAction=Instance.new('InputAction'); directAction.Type=Enum.InputActionType.Bool; directAction.Parent=profile
local directKey=Instance.new('InputBinding'); directKey.Type=Enum.InputBindingType.Scriptable; directKey.Parent=directAction
local requested={.2,0,0}; local direct=inputs:bindHold(directAction,'Aim',requested); requested[1]=1
directKey:Fire(true); task.wait(); actor:step(.01)
assert(ball.Transform:FuzzyEq(CFrame.Angles(.2,0,0),.001),'vector hold must copy the supplied value')
direct:destroy(); actor:step(.01)
assert(ball.Transform:FuzzyEq(CFrame.identity,.001),'destroying an active vector hold must reset it')
inputs:destroy(); actor:destroy(); profile:Destroy(); model:Destroy()
return 'Generated input profile drives hinge and ball controls and impulses'
