local Solver=require('../src/shared/Solver')
local Limits=require('../src/shared/Limits')
local solver=Solver.new(Limits)
local I={0,0,0,1}
local q90={0,0,math.sin(math.pi/4),math.cos(math.pi/4)}
local function chain(limit)
 return {root={0,0,0},joints={{rest=I,rotation=I,offset={1,0,0}}, {rest=I,rotation=I,offset={0,0,0},limit=limit}}}
end
local options={iterations=30,tolerance=1e-6,targetOrientation=q90,orientationTolerance=1e-5}
local solved=solver.solve(chain(),{1,0,0},options)
assert(solved.converged and solved.orientationConverged,'position and orientation should converge with a free end joint')
assert(solved.error<1e-6 and solved.orientationError<1e-5,'report the achieved pose errors')
local negative=solver.solve(chain(),{1,0,0},{iterations=30,tolerance=1e-6,targetOrientation={-q90[1],-q90[2],-q90[3],-q90[4]},orientationTolerance=1e-5})
assert(negative.converged and negative.orientationError<1e-5,'opposite quaternion signs describe the same orientation')
local lockedChain=chain({kind='Hinge',axis={0,0,1},lower=0,upper=.2})
lockedChain.joints[1].weight=0
local limited=solver.solve(lockedChain,{1,0,0},options)
assert(not limited.converged and not limited.orientationConverged and limited.orientationError>.1,'constrained pose must report orientation shortfall')
local mismatch=solver.solve(chain(),{1,0,0},{iterations=1,tolerance=0,targetOrientation=I,orientationTolerance=1e-5,endpointOrientation=q90,maxStep=.2})
assert(mismatch.orientationError>.1,'endpoint frame rotation must be included')
assert(not pcall(function() solver.solve(chain(),{1,0,0},{iterations=1,tolerance=0,targetOrientation={0/0,0,0,1}}) end),'invalid orientation must be rejected')
assert(not pcall(function() solver.solve(chain(),{1,0,0},{iterations=1,tolerance=0,targetOrientation=I,orientationTolerance=-1}) end),'invalid orientation tolerance must be rejected')
local articulated={root={0,0,0},joints={{rest=I,rotation=I,offset={1,0,0}},{rest=I,rotation=I,offset={1,0,0}}}}
local bent=solver.solve(articulated,{1+math.cos(.2),math.sin(.2),0},{iterations=500,tolerance=.001,targetOrientation=I,orientationTolerance=.001})
assert(bent.converged, 'coupled reachable pose should converge, position='..bent.error..' orientation='..bent.orientationError)
print('orientation solver tests passed')
