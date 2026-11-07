local model=Instance.new('Model')
local part=Instance.new('Part'); part.CFrame=CFrame.new(1,2,3)*CFrame.Angles(.1,.2,.3); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.C0=CFrame.new(.5,0,0)*CFrame.Angles(0,.4,0); motor.Parent=part
local parentBone=Instance.new('Bone'); parentBone.CFrame=CFrame.new(0,1,0)*CFrame.Angles(.2,0,0); parentBone.Transform=CFrame.Angles(0,.3,0); parentBone.Parent=part
local bone=Instance.new('Bone'); bone.CFrame=CFrame.new(.5,0,0)*CFrame.Angles(0,0,.2); bone.Transform=CFrame.Angles(.5,0,0); bone.Parent=parentBone
local holder=Instance.new('Folder')
local gizmo=AxisGizmo.new(holder)
assert(gizmo:update(motor))
local x=holder:FindFirstChild('EditRigIKAxisX'); assert(x and x.Adornee==part)
assert((part.CFrame*x.CFrame):FuzzyEq(part.CFrame*motor.C0,1e-5),'Motor6D axes use rest frame')
assert(gizmo:update(bone))
assert(x.Adornee==part and (part.CFrame*x.CFrame):FuzzyEq(parentBone.TransformedWorldCFrame*bone.CFrame,1e-5),'Bone axes use transformed parent and rest frame')
motor.Part0=nil
assert(not gizmo:update(motor) and x.Adornee==nil,'invalid joints clear visualization')
gizmo:destroy(); assert(#holder:GetChildren()==0)
model:Destroy(); holder:Destroy()
return 'Axis gizmo rest frames and cleanup passed'
