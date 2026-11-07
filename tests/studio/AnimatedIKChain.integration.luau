local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local tip=Instance.new('Part'); tip.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.Part1=tip; motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
for _,joint in ipairs({motor,bone}) do
 local fixed=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true},Solver.new(Limits))
 joint.Transform=CFrame.Angles(0,0,.1)
 assert(not pcall(function() fixed:solve(Vector3.yAxis,{iterations=10,tolerance=.001}) end),'fixed mode must reject external writes')
 fixed:destroy(); joint.Transform=CFrame.identity
 local animated=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,baseMode='animated'},Solver.new(Limits))
 local first=CFrame.Angles(0,0,.3); joint.Transform=first
 assert(animated:solve(Vector3.yAxis,{iterations=10,tolerance=.001}).converged,'animated base should solve')
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5),'solver must apply pose from animated base')
 assert(animated:solve(Vector3.yAxis,{iterations=10,tolerance=.001}).converged,'repeated solve must not accumulate')
 local second=CFrame.Angles(0,0,-.2); joint.Transform=second
 assert(animated:solve(Vector3.yAxis,{iterations=10,tolerance=.001}).converged,'fresh animated base should solve')
 assert(#animated:destroy()==0 and joint.Transform:FuzzyEq(second,1e-5),'destroy must restore latest observed animation base')
 joint.Transform=CFrame.identity
 local later=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,baseMode='animated'},Solver.new(Limits))
 later:solve(Vector3.yAxis,{iterations=10,tolerance=.001})
 local external=CFrame.Angles(0,0,.4); joint.Transform=external
 assert(#later:destroy()==1 and joint.Transform:FuzzyEq(external,1e-5),'cleanup must preserve a later external write')
 joint.Transform=CFrame.identity
 local translated=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,baseMode='animated'},Solver.new(Limits))
 joint.Transform=CFrame.new(1,0,0)
 assert(not pcall(function() translated:solve(Vector3.yAxis,{iterations=10,tolerance=.001}) end),'translated animated bases must be rejected')
 assert(joint.Transform.Position.X==1,'rejected base must not be overwritten')
 translated:destroy(); joint.Transform=CFrame.identity
 local limited=ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,baseMode='animated'},Solver.new(Limits))
 local opts={iterations=10,tolerance=.001,maxAngularSpeed=math.rad(90),dt=.25}
 limited:solve(Vector3.yAxis,opts)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(22.5)),1e-5),'first animated solve must respect the speed cap')
 joint.Transform=CFrame.Angles(0,0,-math.pi/2)
 limited:solve(Vector3.yAxis,opts)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(45)),1e-5),'speed cap must measure from the previous IK output even when the animated base changes')
 limited:destroy(); joint.Transform=CFrame.identity
 assert(not pcall(function() ChainAdapter.new({joint},Vector3.xAxis,{exclusive=true,baseMode='invalid'},Solver.new(Limits)) end),'invalid base mode must be rejected')
end
model:Destroy()
return 'Animated IK chain accepts changing Motor6D and Bone bases and restores safely'
