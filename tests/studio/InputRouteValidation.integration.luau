local model=Instance.new('Model'); local motor=Instance.new('Motor6D'); motor.Parent=model
local folder=Instance.new('Folder'); folder.Parent=model; folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local ref=Instance.new('ObjectValue'); ref.Name='Jaw'; ref.Value=motor; ref.Parent=folder
ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
ref:SetAttribute('Control','Bite'); ref:SetAttribute('Impulse','Snap'); ref:SetAttribute('Frequency',4)
local actor=ActorRig.new(folder,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
local inputs=InputBindings.new(actor)
local action=Instance.new('InputAction'); action.Type=Enum.InputActionType.Bool
assert(not pcall(function() inputs:bindImpulse(action,'Typo',1) end),'unknown impulse must fail when bound')
assert(not pcall(function() inputs:bindImpulse(action,'Snap',{1,2,3}) end),'wrong payload type must fail when bound')
local profile=Instance.new('InputContext'); profile.Enabled=false
local hold=Instance.new('InputAction'); hold.Type=Enum.InputActionType.Bool; hold:SetAttribute('Route','Hold'); hold:SetAttribute('Control','Bite'); hold:SetAttribute('Value',1); hold.Parent=profile
local bad=Instance.new('InputAction'); bad.Type=Enum.InputActionType.Bool; bad:SetAttribute('Route','Impulse'); bad:SetAttribute('Control','Missing'); bad:SetAttribute('Value',1); bad.Parent=profile
actor:setControl('Bite',.5)
assert(not pcall(function() inputs:bindProfile(profile) end),'stale profile must fail before binding')
actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/4),1e-5),'invalid profile must not reset a valid control')
bad:SetAttribute('Control','Snap')
local handle=inputs:bindProfile(profile); handle:destroy(); inputs:destroy(); actor:destroy()
profile:Destroy(); action:Destroy(); model:Destroy()
return 'Input routes validate before binding without changing actor state'
