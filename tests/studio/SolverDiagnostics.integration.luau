local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local endPart=Instance.new('Part'); endPart.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.Part1=endPart; motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local solver=Solver.new(Limits)
for _,joint in ipairs({motor,bone}) do
 local adapter=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,limits={{kind='Hinge',axis={0,0,1},lower=0,upper=math.pi/4}}},solver)
 local constrained=adapter:solve(Vector3.yAxis,{iterations=4,tolerance=.001})
 assert(constrained.status=='notConverged' and constrained.limitedJoints[1]==1 and #constrained.limitedJoints==1,'clamped limit must be reported')
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/4),1e-5),'reported joint must be limited in actual transform')
 local outside=adapter:solve(Vector3.new(3,0,0),{iterations=4,tolerance=.001})
 assert(outside.status=='outsideReach' and math.abs(outside.maxReach-1)<1e-6,'outside maximum reach must be reported')
 adapter:destroy()
end
model:Destroy()
return 'Solver diagnostics identify reach and limit effects for Motor6D and Bone'
