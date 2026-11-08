-- Run with Solver, Limits and ChainAdapter in scope, on disposable instances.
local holder=Instance.new('Model')
local part=Instance.new('Part'); part.CFrame=CFrame.new(2,3,4)*CFrame.Angles(.2,.3,.4); part.Parent=holder
local nextPart=Instance.new('Part'); nextPart.Parent=holder
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.Part1=nextPart; motor.C0=CFrame.Angles(.3,0,.1); motor.C1=CFrame.Angles(0,.4,.2); motor.Parent=part
local endpointOrientation=CFrame.Angles(.1,.2,.3)
local solver=Solver.new(Limits)
local desiredLocal=CFrame.Angles(.2,.4,-.3)
local targetFrame=part.CFrame*motor.C0*desiredLocal*motor.C1:Inverse()*CFrame.new(1,0,0)*endpointOrientation
local adapter=ChainAdapter.new({motor},Vector3.xAxis,{exclusive=true,endpointOrientation=endpointOrientation},solver)
local result=adapter:solve(targetFrame.Position,{iterations=150,tolerance=.001,targetOrientation=targetFrame.Rotation,orientationTolerance=.001,maxStep=.25})
local actual=part.CFrame*motor.C0*motor.Transform*motor.C1:Inverse()*CFrame.new(1,0,0)*endpointOrientation
assert(result.converged and result.orientationConverged,'Motor6D target pose must converge')
assert((actual.Position-targetFrame.Position).Magnitude<.002 and actual.Rotation:FuzzyEq(targetFrame.Rotation,.002),'Motor6D final attachment frame must match the desired pose')
assert(result.endpointOrientationWorld:FuzzyEq(actual.Rotation,1e-5),'Motor6D orientation diagnostic must match actual endpoint')
adapter:destroy()
local root=Instance.new('Bone'); root.CFrame=CFrame.Angles(.3,.2,.1); root.Parent=part
local boneFrame=part.CFrame*root.CFrame*desiredLocal*CFrame.new(1,0,0)*endpointOrientation
local bone=ChainAdapter.new({root},Vector3.xAxis,{exclusive=true,endpointOrientation=endpointOrientation},solver)
local b=bone:solve(boneFrame.Position,{iterations=150,tolerance=.001,targetOrientation=boneFrame.Rotation,orientationTolerance=.001,maxStep=.25})
local boneActual=part.CFrame*root.CFrame*root.Transform*CFrame.new(1,0,0)*endpointOrientation
assert(b.converged and b.orientationConverged and boneActual.Rotation:FuzzyEq(boneFrame.Rotation,.002),'Bone attachment orientation must be solved')
bone:destroy()
local capped=ChainAdapter.new({root},Vector3.xAxis,{exclusive=true,endpointOrientation=endpointOrientation},solver)
local limited=capped:solve(boneFrame.Position,{iterations=150,tolerance=.001,targetOrientation=boneFrame.Rotation,orientationTolerance=.001,maxAngularSpeed=.1,dt=.1})
local cappedActual=part.CFrame*root.CFrame*root.Transform*CFrame.new(1,0,0)*endpointOrientation
assert(limited.motionLimited and not limited.converged and not limited.orientationConverged,'speed-capped diagnostics must reflect the applied pose')
assert(limited.endpointOrientationWorld:FuzzyEq(cappedActual.Rotation,1e-5),'speed-capped orientation must be the actual orientation')
capped:destroy(); holder:Destroy()
return 'Motor6D and Bone endpoint orientation passed'
