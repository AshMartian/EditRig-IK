local runtime=RuntimeFactory({Solver=Solver,Limits=Limits,Actor=Actor,JointDrive=JointDrive,StepTrajectory=StepTrajectory,FootstepBehavior=FootstepBehavior,JointAdapter=JointAdapter,ChainAdapter=ChainAdapter,ChainDefinition=ChainDefinition,ActorRig=ActorRig,Ownership=Ownership},function(module) return module end)
local model=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=a; motor.Part1=b; motor.Parent=a
local folder=Instance.new('Folder'); folder.Name='EditRigIKActor'; folder.Parent=model; folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
local ref=Instance.new('ObjectValue'); ref.Name='Joint'; ref.Value=motor; ref.Parent=folder
ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
ref:SetAttribute('Control','joint'); ref:SetAttribute('Impulse','tap'); ref:SetAttribute('Frequency',4)
local actor=runtime.createActor(folder,{exclusive=true})
assert(not pcall(function() runtime.createIKChain({motor},Vector3.xAxis,{exclusive=true}) end),'actor and chain must share ownership')
assert(not pcall(function() runtime.createActor(folder,{exclusive=true}) end),'two actors must not own the same joint')
actor:destroy()
local chain=runtime.createIKChain({motor},Vector3.xAxis,{exclusive=true})
assert(not pcall(function() runtime.createActor(folder,{exclusive=true}) end),'chain ownership must also block actor creation')
chain:destroy()
local restarted=runtime.createActor(folder,{exclusive=true}); restarted:destroy()
model:Destroy()
return 'Runtime actor and chain ownership integration passed'
