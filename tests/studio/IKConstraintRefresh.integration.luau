local model=Instance.new('Model'); local a=Instance.new('Part'); a.Parent=model; local b=Instance.new('Part'); b.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Elbow'; motor.Part0=a; motor.Part1=b; motor.Parent=a
motor:SetAttribute('EditRigIK_SchemaVersion',1); motor:SetAttribute('EditRigIK_Kind','Hinge'); motor:SetAttribute('EditRigIK_Axis','X')
motor:SetAttribute('EditRigIK_LowerDegrees',-30); motor:SetAttribute('EditRigIK_UpperDegrees',30); motor:SetAttribute('EditRigIK_SwingDegrees',90)
local builder=IKConstraintBuilder.new(Config); local created=builder.apply(builder.prepare(motor))
assert(created:GetAttribute('EditRigIK_ConstraintVersion')==1,'generated constraint must identify ownership')
local ref=created:FindFirstChild('EditRigIKJoint'); assert(ref and ref:IsA('ObjectValue') and ref.Value==motor,'constraint must identify its source joint')
local a0,a1=created.Attachment0,created.Attachment1
created.Enabled=false
motor.C0=CFrame.new(2,0,0); motor:SetAttribute('EditRigIK_Axis','Z'); motor:SetAttribute('EditRigIK_LowerDegrees',-10); motor:SetAttribute('EditRigIK_UpperDegrees',35)
local plan=builder.prepareRefresh(motor); builder.refresh(plan)
assert(created.Attachment0==a0 and created.Attachment1==a1 and not created.Enabled,'refresh must preserve objects and enabled state')
assert(created.LowerAngle==-10 and created.UpperAngle==35 and a0.CFrame:FuzzyEq(motor.C0*CFrame.Angles(0,-math.pi/2,0),1e-5),'refresh must apply current hinge metadata and geometry')
local unchanged=a0.CFrame
local other=Instance.new('RopeConstraint'); other.Attachment0=a0; other.Parent=model
assert(not pcall(builder.prepareRefresh,motor),'shared attachments must not be modified')
assert(a0.CFrame==unchanged,'rejected refresh must not modify attachments'); other:Destroy()
plan=builder.prepareRefresh(motor); motor:SetAttribute('EditRigIK_UpperDegrees',40)
assert(not pcall(builder.refresh,plan),'metadata changed after preparation must be rejected')
assert(created.UpperAngle==35,'stale plan must not partially write')
motor:SetAttribute('EditRigIK_Kind','Ball'); assert(not pcall(builder.prepareRefresh,motor),'changing constraint kind must not replace the object')
motor:SetAttribute('EditRigIK_Kind','Hinge'); ref.Value=nil
assert(not pcall(builder.prepareRefresh,motor),'unknown or altered ownership must be rejected')
a0:Destroy(); a1:Destroy(); created:Destroy()
motor:SetAttribute('EditRigIK_Kind','Ball'); motor:SetAttribute('EditRigIK_SwingDegrees',25)
local socket=builder.apply(builder.prepare(motor)); local socket0=socket.Attachment0
motor:SetAttribute('EditRigIK_Axis','Y'); motor:SetAttribute('EditRigIK_SwingDegrees',55)
motor:SetAttribute('EditRigIK_LowerDegrees',-15); motor:SetAttribute('EditRigIK_UpperDegrees',80)
builder.refresh(builder.prepareRefresh(motor))
assert(socket.UpperAngle==55 and socket.TwistLowerAngle==-15 and socket.TwistUpperAngle==80 and socket.TwistLimitsEnabled,'refresh must update ball swing and twist')
assert(socket.Attachment0==socket0 and socket0.CFrame:FuzzyEq(motor.C0*CFrame.Angles(0,0,math.pi/2),1e-5),'ball refresh must preserve attachment and update axis')
model:Destroy()
return 'Generated hinge and ball refresh validates ownership and updates in place'
