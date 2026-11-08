assert(type(AxisGizmo.restFrame)=='function','joint guide must expose a shared rest-frame calculation')
local model=Instance.new('Model')
local part=Instance.new('Part'); part.CFrame=CFrame.new(1,2,3)*CFrame.Angles(.1,.2,.3); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.C0=CFrame.new(.5,0,0)*CFrame.Angles(0,.4,0); motor.Parent=part
local parentBone=Instance.new('Bone'); parentBone.CFrame=CFrame.new(0,1,0)*CFrame.Angles(.2,0,0); parentBone.Transform=CFrame.Angles(0,.3,0); parentBone.Parent=part
local bone=Instance.new('Bone'); bone.CFrame=CFrame.new(.5,0,0)*CFrame.Angles(0,0,.2); bone.Transform=CFrame.Angles(.5,0,0); bone.Parent=parentBone
motor.Transform=CFrame.Angles(.6,-.3,.4)
local motorAnchor,motorRest=AxisGizmo.restFrame(motor)
assert(motorAnchor==part and motorRest:FuzzyEq(part.CFrame*motor.C0,1e-5),'Motor6D rest frame must include the rotated part and C0, but not the selected motor transform')
local boneAnchor,boneRest=AxisGizmo.restFrame(bone)
local expectedBoneRest=part.CFrame*parentBone.CFrame*parentBone.Transform*bone.CFrame
assert(boneAnchor==part and boneRest:FuzzyEq(expectedBoneRest,1e-5),'Bone rest frame must include the animated parent but not the selected bone transform')
bone.Transform=CFrame.Angles(-.2,.7,-.4)
local _,unchangedBoneRest=AxisGizmo.restFrame(bone)
assert(unchangedBoneRest:FuzzyEq(expectedBoneRest,1e-5),'selected bone transform must not rotate the guide frame')
local _,parentBoneRest=AxisGizmo.restFrame(parentBone)
assert(parentBoneRest:FuzzyEq(part.CFrame*parentBone.CFrame,1e-5),'top-level Bone uses its parent BasePart frame')
local holder=Instance.new('Folder')
local gizmo=AxisGizmo.new(holder,LimitGeometry.new(Config))
assert(type(AxisGizmo.toWorldSegments)=='function','joint guide geometry must be transformed into world space')
local frame=CFrame.new(5,6,7)*CFrame.Angles(0,0,math.pi/2)
local transformed=AxisGizmo.toWorldSegments(frame,{{Vector3.zero,Vector3.xAxis}})
assert((transformed[1][1]-Vector3.new(5,6,7)).Magnitude<1e-5 and (transformed[1][2]-Vector3.new(5,7,7)).Magnitude<1e-5,'joint guides must follow translated and rotated frames')
assert(gizmo:update(motor))
local x=holder:FindFirstChild('EditRigIKAxisX'); assert(x and x.Adornee==part)
assert(x.Thickness>=3,'axis lines must be visible enough for editing')
assert(gizmo:setLimits({kind='Hinge',axis='Z',lower=-30,upper=60,swing=45}))
assert(gizmo:update(motor))
local limit=holder:FindFirstChild('EditRigIKLimit'); assert(limit and limit.Adornee==part)
local twist=holder:FindFirstChild('EditRigIKTwist'); assert(twist and twist.Adornee==nil,'hinges must not display a ball twist guide')
local ball={kind='Ball',axis='Z',lower=-30,upper=60,swing=45}
local cone,arc=LimitGeometry.new(Config).build(ball)
assert(#cone==52 and #arc>=50,'ball guide must show distinct swing and twist ranges')
local center=Vector3.zAxis*1.3
local function expected(angle) return center+(Vector3.xAxis*math.cos(math.rad(angle))+Vector3.yAxis*math.sin(math.rad(angle)))*.6 end
assert((arc[1][1]-expected(-30)).Magnitude<1e-5,'twist starts at the signed lower bound')
assert((arc[48][2]-expected(60)).Magnitude<1e-5,'twist ends at the signed upper bound')
for _,axes in ipairs({{Vector3.xAxis,Vector3.yAxis,'X'}, {Vector3.yAxis,Vector3.zAxis,'Y'}, {Vector3.zAxis,Vector3.xAxis,'Z'}}) do
 local axis,reference,name=axes[1],axes[2],axes[3]
 local _,testArc=LimitGeometry.new(Config).build({kind='Ball',axis=name,lower=-45,upper=35,swing=25})
 local expectedLower=axis*1.3+CFrame.fromAxisAngle(axis,math.rad(-45)):VectorToWorldSpace(reference)*.6
 local expectedUpper=axis*1.3+CFrame.fromAxisAngle(axis,math.rad(35)):VectorToWorldSpace(reference)*.6
 assert((testArc[1][1]-expectedLower).Magnitude<1e-5 and (testArc[48][2]-expectedUpper).Magnitude<1e-5,'signed twist follows the right-handed solver axis for '..name)
end
local worldArc=AxisGizmo.toWorldSegments(motorRest,arc)
assert((worldArc[1][1]-motorRest:PointToWorldSpace(expected(-30))).Magnitude<1e-5,'twist guide follows rotated joint rest frames')
assert(gizmo:setLimits(ball) and gizmo:update(motor) and twist.Adornee==part,'ball twist guide must render separately')
assert(not gizmo:setLimits({kind='Hinge',axis='Z',lower=90,upper=-90,swing=45}))
assert(limit.Adornee==nil and twist.Adornee==nil,'invalid unsaved settings must hide both limit markers')
assert(gizmo:update(bone))
assert(x.Adornee==part,'Bone axes use the bone ancestor part')
motor.Part0=nil
assert(not gizmo:update(motor) and x.Adornee==nil,'invalid joints clear visualization')
gizmo:destroy(); assert(#holder:GetChildren()==0)
model:Destroy(); holder:Destroy()
return 'Axis gizmo rest frames and cleanup passed'
