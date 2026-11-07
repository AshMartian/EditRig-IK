local model=Instance.new('Model')
local motor=Instance.new('Motor6D'); motor.Parent=model
local folder=Instance.new('Folder'); folder.Parent=model; folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local ref=Instance.new('ObjectValue'); ref.Name='Jaw'; ref.Value=motor; ref.Parent=folder
ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
ref:SetAttribute('Control','Bite'); ref:SetAttribute('Impulse','Snap'); ref:SetAttribute('Frequency',4)
local actor=ActorRig.new(folder,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
local context=Instance.new('InputContext')
local hold=Instance.new('InputAction'); hold.Type=Enum.InputActionType.Bool; hold.Parent=context
local holdInput=Instance.new('InputBinding'); holdInput.Type=Enum.InputBindingType.Scriptable; holdInput.Parent=hold
local fire=Instance.new('InputAction'); fire.Type=Enum.InputActionType.Bool; fire.Parent=context
local fireInput=Instance.new('InputBinding'); fireInput.Type=Enum.InputBindingType.Scriptable; fireInput.Parent=fire
local bindings=InputBindings.new(actor)
bindings:bindHold(hold,'Bite',1)
assert(not pcall(function() bindings:bindHold(hold,'Bite',1) end),'duplicate hold writers must be rejected')
bindings:bindImpulse(fire,'Snap',1)
holdInput:Fire(true); task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5),'held action should drive named control')
hold.Enabled=false; task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5),'disabled action should reset control')
hold.Enabled=true; holdInput:Fire(true); task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5),'re-enabled action should work')
holdInput:Fire(false); task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5),'released action should reset control')
fireInput:Fire(true); task.wait(); actor:step(.1)
assert(not motor.Transform:FuzzyEq(CFrame.identity,1e-5),'pressed action should send an impulse')
holdInput:Fire(true); task.wait()
bindings:destroy(); actor:step(3)
assert(motor.Transform:FuzzyEq(CFrame.identity,.001),'destroy should reset held controls')
assert(not pcall(function() bindings:bindHold(hold,'Bite',1) end),'destroyed manager must reject bindings')
local second=InputBindings.new(actor)
second:bindHold(hold,'Bite',1)
actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),.001),'binding an already held action must synchronize immediately')
hold.Type=Enum.InputActionType.Direction1D; task.wait(); actor:step(3)
assert(motor.Transform:FuzzyEq(CFrame.identity,.001),'changing action type must release the hold')
hold.Type=Enum.InputActionType.Bool
second:bindHold(hold,'Bite',1)
holdInput:Fire(true); task.wait()
hold:Destroy(); task.wait(); actor:step(3)
assert(motor.Transform:FuzzyEq(CFrame.identity,.001),'destroying an action must release its held control')
second:destroy()
actor:destroy(); context:Destroy(); model:Destroy()
return 'InputAction bindings drive and release an authored joint'
