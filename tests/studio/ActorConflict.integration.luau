local model=Instance.new('Model')
local motor=Instance.new('Motor6D'); motor.Parent=model
local boneParent=Instance.new('Part'); boneParent.Parent=model
local bone=Instance.new('Bone'); bone.Parent=boneParent
local definition=Instance.new('Folder'); definition.Parent=model; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1)
for _,e in ipairs({{'A',motor},{'B',bone}}) do
 local ref=Instance.new('ObjectValue'); ref.Name=e[1]; ref.Value=e[2]; ref.Parent=definition
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control',e[1]); ref:SetAttribute('Impulse','Tap'); ref:SetAttribute('Frequency',4)
end
local actor=ActorRig.new(definition,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
actor:impulse('Tap',1)
bone.Transform=CFrame.Angles(.2,0,0)
assert(not pcall(function() actor:step(.1) end),'external transform must reject the update')
bone.Transform=CFrame.identity
local values=actor:step(.1)
local expected=.1*math.exp(-.4)
assert(math.abs(values.A-expected)<1e-6 and math.abs(values.B-expected)<1e-6,'rejected update must not consume impulse or advance behavior')
assert(#actor:destroy()==0); model:Destroy()
return 'Actor preserves impulse when a conflicting joint rejects an update'
