local model=Instance.new('Model'); local root=Instance.new('Part'); root.Parent=model
local tip=Instance.new('Part'); tip.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=root; motor.Part1=tip; motor.Parent=root
local bone=Instance.new('Bone'); bone.Parent=root
for _,joint in ipairs({motor,bone}) do
 local chain=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true},Solver.new(Limits))
 local options={iterations=10,tolerance=.001,maxAngularSpeed=math.rad(90),dt=.25}
 local result=chain:solve(Vector3.yAxis,options)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(22.5)),1e-5),'first solve must obey time-based speed')
 assert(result.motionLimited and not result.converged,'rate-limited pose must not report solver candidate convergence')
 local expected=Vector3.new(math.cos(math.rad(22.5)),math.sin(math.rad(22.5)),0)
 assert((result.endpointWorld-expected).Magnitude<1e-5,'diagnostics must describe applied endpoint')
 assert(math.abs(result.error-(Vector3.yAxis-expected).Magnitude)<1e-5,'diagnostics must report applied error')
 chain:solve(Vector3.yAxis,options)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(45)),1e-5),'speed cap must apply on every solve')
 local before=joint.Transform
 assert(not pcall(function() chain:solve(Vector3.yAxis,{iterations=10,tolerance=.001,maxAngularSpeed=1,dt=-1}) end),'invalid dt must be rejected')
 assert(joint.Transform:FuzzyEq(before,1e-5),'invalid timing must not change joints')
 local final=chain:solve(Vector3.yAxis,{iterations=10,tolerance=.001})
 assert(final.converged and not final.motionLimited,'old uncapped solve must remain available')
 chain:destroy()
end
local tiny=ChainAdapter.new({motor},Vector3.xAxis,{exclusive=true},Solver.new(Limits))
local small=tiny:solve(Vector3.new(math.cos(.001),math.sin(.001),0),{iterations=10,tolerance=0,maxAngularSpeed=.01,dt=.01})
assert(small.motionLimited and motor.Transform.RightVector.Y<.00011,'small rotations must still obey the speed cap')
tiny:destroy()
model:Destroy()
return 'Time-based speed caps apply to Motor6D and Bone and report applied pose'
