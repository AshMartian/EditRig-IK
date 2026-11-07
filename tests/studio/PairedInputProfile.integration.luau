local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
local function add(name,joint,kind,axis,control,forward,reverse,value)
 joint:SetAttribute('EditRigIK_HoldKey',forward); joint:SetAttribute('EditRigIK_ReverseHoldKey',reverse); joint:SetAttribute('EditRigIK_HoldValue',value)
 local ref=Instance.new('ObjectValue'); ref.Name=name; ref.Value=joint; ref.Parent=definition
 ref:SetAttribute('Kind',kind); ref:SetAttribute('Axis',axis); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90); ref:SetAttribute('SwingDegrees',90)
 ref:SetAttribute('Control',control); ref:SetAttribute('Frequency',4)
end
add('Jaw',motor,'Hinge','Z','Jaw','E','Q',.5)
add('Neck',bone,'Ball','X','Neck','D','A',.3)
local context=InputProfileBuilder.create(definition)
local actions={}
for _,a in ipairs(context:GetChildren()) do
 local id=a:GetAttribute('Control')..a:GetAttribute('Route'); actions[id]=a
 for _,b in ipairs(a:GetChildren()) do b:Destroy() end
 local b=Instance.new('InputBinding'); b.Type=Enum.InputBindingType.Scriptable; b.Parent=a
end
assert(actions.JawAxisPositive and actions.JawAxisNegative and actions.NeckAxisPositive and actions.NeckAxisNegative,'both directions must be generated')
local components={Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter,BallDrive={new=function(o) return BallDrive.new(o,Limits) end}}
local actor=ActorRig.new(definition,components); local bindings=InputBindings.new(actor); local profile=bindings:bindProfile(context)
context.Enabled=true; actions.JawAxisNegative.InputBinding:Fire(true); actions.NeckAxisPositive.InputBinding:Fire(true); task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,-math.pi/4),1e-5),'negative key must drive hinge')
assert(bone.Transform:FuzzyEq(CFrame.Angles(.3,0,0),1e-5),'positive key must drive bone')
actions.JawAxisPositive.InputBinding:Fire(true); task.wait(); actor:step(.01)
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5),'opposite keys must cancel')
profile:destroy(); actor:step(.01); assert(bone.Transform:FuzzyEq(CFrame.identity,1e-5),'closing profile must release axis')
bindings:destroy(); actor:destroy(); context:Destroy()
local invalid=Instance.new('InputContext'); invalid.Enabled=false
local validHold=Instance.new('InputAction'); validHold.Type=Enum.InputActionType.Bool; validHold.Parent=invalid
validHold:SetAttribute('Route','Hold'); validHold:SetAttribute('Control','First'); validHold:SetAttribute('Value',1)
local incomplete=Instance.new('InputAction'); incomplete.Type=Enum.InputActionType.Bool; incomplete.Parent=invalid
incomplete:SetAttribute('Route','AxisPositive'); incomplete:SetAttribute('Control','Second'); incomplete:SetAttribute('Value',1)
local writes=0; local probe=InputBindings.new({setControl=function() writes+=1 end,impulse=function() end})
assert(not pcall(function() probe:bindProfile(invalid) end) and writes==0,'invalid axis must be rejected before any control writes')
probe:destroy(); invalid:Destroy()
motor:SetAttribute('EditRigIK_ReverseHoldKey','E')
assert(not pcall(InputProfileBuilder.create,definition),'same key cannot drive opposing actions')
motor:SetAttribute('EditRigIK_HoldKey','')
assert(not pcall(InputProfileBuilder.create,definition),'reverse key needs a forward key')
model:Destroy()
return 'Paired generated profiles drive Motor6D and Bone axes'
