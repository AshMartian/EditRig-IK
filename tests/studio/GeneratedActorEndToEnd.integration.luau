local model=Instance.new('Model')
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Jaw'; motor.Parent=part
local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=part
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
for _,entry in ipairs({{'Jaw',motor},{'Tail',bone}}) do
 local joint=entry[2]; joint:SetAttribute('EditRigIK_HoldKey','E')
 local ref=Instance.new('ObjectValue'); ref.Name=entry[1]; ref.Value=joint; ref.Parent=definition
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control','Bite'); ref:SetAttribute('Frequency',4)
end
local context=InputProfileBuilder.create(definition)
local action=context:FindFirstChildWhichIsA('InputAction')
for _,binding in ipairs(action:GetChildren()) do binding:Destroy() end
local key=Instance.new('InputBinding'); key.Type=Enum.InputBindingType.Scriptable; key.Parent=action
local tick=Instance.new('BindableEvent'); local module=Instance.new('ModuleScript'); module.Name='EditRigIKRuntime'
local fakeStorage={FindFirstChild=function(_,name) if name=='EditRigIKRuntime' then return module end end}
local fakeGame={GetService=function(_,name) if name=='ReplicatedStorage' then return fakeStorage elseif name=='RunService' then return {PreSimulation=tick.Event} end error('unexpected service') end}
local controller=GeneratedControllerFactory({Parent=model},fakeGame,function(item) assert(item==module); return Runtime end)
local inputs,handle,message
local actor=controller.run({exclusive=true},function(err) message=err; handle:destroy(); inputs:destroy() end)
inputs=Runtime.InputBindings.new(actor); handle=inputs:bindProfile(context)
context.Enabled=true; key:Fire(true); task.wait(); tick:Fire(.1); task.wait()
local target=CFrame.Angles(0,0,math.pi/2)
assert(motor.Transform:FuzzyEq(target,1e-5) and bone.Transform:FuzzyEq(target,1e-5),'input and generated loop should drive both joint types')
local external=CFrame.Angles(.2,0,0); bone.Transform=external
tick:Fire(.1); task.wait()
assert(message and string.find(message,'another writer',1,true),'conflicting writer must reach error handler')
assert(not pcall(controller.get),'failed loop must release actor')
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5) and bone.Transform:FuzzyEq(external,1e-5),'cleanup restores owned joints and preserves conflict')
bone.Transform=CFrame.identity
local restarted=controller.start({exclusive=true}); assert(restarted,'claims must be reusable'); controller.stop()
context:Destroy(); tick:Destroy(); module:Destroy(); model:Destroy()
return 'Generated controller, input profile, joint updates and conflict cleanup work together'
