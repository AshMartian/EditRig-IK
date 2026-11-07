local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local hinge=Instance.new('Motor6D'); hinge.Parent=part; local ball=Instance.new('Bone'); ball.Parent=part
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
local function add(name,joint,kind,control,impulse,holdKey,impulseKey,holdValue,impulseValue)
 joint:SetAttribute('EditRigIK_HoldKey',holdKey); joint:SetAttribute('EditRigIK_ImpulseKey',impulseKey)
 joint:SetAttribute('EditRigIK_HoldValue',holdValue); joint:SetAttribute('EditRigIK_ImpulseValue',impulseValue)
 local ref=Instance.new('ObjectValue'); ref.Name=name; ref.Value=joint; ref.Parent=definition
 ref:SetAttribute('Kind',kind); ref:SetAttribute('Axis','X'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('SwingDegrees',90); ref:SetAttribute('Control',control); ref:SetAttribute('Impulse',impulse); ref:SetAttribute('Frequency',4)
end
add('Jaw',hinge,'Hinge','Bite','Snap','E','',-.5,1)
add('Shoulder',ball,'Ball','Aim','Nudge','F','Q',-.3,-2)
local context=InputProfileBuilder.create(definition); local actions={}
for _,action in ipairs(context:GetChildren()) do
 local name=action:GetAttribute('Control'); actions[name]=action
 for _,binding in ipairs(action:GetChildren()) do binding:Destroy() end
 local key=Instance.new('InputBinding'); key.Type=Enum.InputBindingType.Scriptable; key.Parent=action
end
assert(actions.Bite:GetAttribute('Value')==-.5 and actions.Aim:GetAttribute('Value')==Vector3.new(-.3,0,0),'signed hold values must be saved')
assert(actions.Nudge:GetAttribute('Value')==Vector3.new(-2,0,0),'signed impulse value must be saved')
local components={Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter,BallDrive={new=function(options) return BallDrive.new(options,Limits) end}}
local actor=ActorRig.new(definition,components); local inputs=InputBindings.new(actor); local profile=inputs:bindProfile(context)
context.Enabled=true; actions.Bite.InputBinding:Fire(true); actions.Aim.InputBinding:Fire(true); task.wait(); actor:step(.01)
assert(hinge.Transform:FuzzyEq(CFrame.Angles(-math.pi/4,0,0),1e-5),'negative hinge value must drive opposite direction')
assert(ball.Transform:FuzzyEq(CFrame.Angles(-.3,0,0),1e-5),'negative ball value must drive opposite direction')
actions.Aim.InputBinding:Fire(false); task.wait(); actions.Nudge.InputBinding:Fire(true); task.wait(); actor:step(.1)
local axis,angle=ball.Transform:ToAxisAngle(); assert(angle>0 and axis.X<0,'negative vector impulse must move in the configured direction')
profile:destroy(); inputs:destroy(); actor:destroy(); context:Destroy(); model:Destroy()
return 'Signed input values drive hinge and ball joints'
