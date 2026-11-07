local model=Instance.new('Model')
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
for _,entry in ipairs({{'Motor',motor},{'Bone',bone}}) do
 local joint=entry[2]; joint:SetAttribute('EditRigIK_HoldKey','E')
 local ref=Instance.new('ObjectValue'); ref.Name=entry[1]; ref.Value=joint; ref.Parent=definition
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control','Bite'); ref:SetAttribute('Frequency',4)
end
local context=InputProfileBuilder.create(definition)
local action=context:FindFirstChildWhichIsA('InputAction'); assert(action and #context:GetChildren()==1)
for _,binding in ipairs(action:GetChildren()) do binding:Destroy() end
local simulated=Instance.new('InputBinding'); simulated.Type=Enum.InputBindingType.Scriptable; simulated.Parent=action
local actor=ActorRig.new(definition,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
local inputs=InputBindings.new(actor); local profile=inputs:bindProfile(context)
context.Enabled=true; simulated:Fire(true); task.wait(); actor:step(.01)
local expected=CFrame.Angles(0,0,math.pi/2)
assert(motor.Transform:FuzzyEq(expected,.001) and bone.Transform:FuzzyEq(expected,.001),'generated profile must drive both joint types')
simulated:Fire(false); task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.identity,.001) and bone.Transform:FuzzyEq(CFrame.identity,.001),'release must reset both joints')
profile:destroy(); inputs:destroy(); actor:destroy(); context:Destroy(); model:Destroy()
return 'Generated input profile drives and releases Motor6D and Bone joints'
