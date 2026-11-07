local Solver = require('../src/shared/Solver')
local Limits = require('../src/shared/Limits')
local function near(a,b,e) assert(math.abs(a-b) < e, tostring(a)..' ~= '..tostring(b)) end
local identity = {0,0,0,1}
local function chain(limit)
    return {root={0,0,0}, joints={
        {rest=identity, rotation=identity, offset={1,0,0}, limit=limit},
        {rest=identity, rotation=identity, offset={1,0,0}},
    }}
end
local solver = Solver.new(Limits)
local result = solver.solve(chain(), {1,1,0}, {iterations=30,tolerance=1e-4})
assert(result.error < 1e-3, 'reachable target should converge: '..result.error)
near(result.endpoint[1],1,0.001); near(result.endpoint[2],1,0.001)
local single = {root={0,0,0},joints={{rest=identity,rotation=identity,offset={1,0,0},limit={kind='Hinge',axis={0,0,1},lower=0,upper=math.pi/4}}}}
local limited = solver.solve(single, {0,1,0}, {iterations=10,tolerance=1e-6})
near(limited.endpoint[1],math.sqrt(.5),1e-5); near(limited.endpoint[2],math.sqrt(.5),1e-5)
assert(limited.error > .5, 'limited target remains unreachable')
local opposite = solver.solve({root={0,0,0},joints={{rest=identity,rotation=identity,offset={1,0,0}}}}, {-1,0,0}, {iterations=3,tolerance=1e-5})
assert(opposite.error < 1e-5, 'antiparallel solve must remain finite and reach target')
assert(not pcall(function() solver.solve(chain(), {0/0,0,0}, {iterations=3,tolerance=0.001}) end))
assert(not pcall(function() solver.solve(chain(), {0,0,0}, {iterations=0,tolerance=0.001}) end))
-- Existing animation may already violate a limit even if the target is met.
local initial = {root={0,0,0},joints={{rest=identity,rotation={0,0,math.sin(math.pi/4),math.cos(math.pi/4)},offset={1,0,0},limit={kind='Hinge',axis={0,0,1},lower=0,upper=math.pi/4}}}}
local enforced = solver.solve(initial, {0,1,0}, {iterations=3,tolerance=1e-5})
near(enforced.endpoint[1],math.sqrt(.5),1e-5)
near(initial.joints[1].rotation[3],math.sin(math.pi/4),1e-6)
local hingedHalfTurn = solver.solve({root={0,0,0},joints={{rest=identity,rotation=identity,offset={1,0,0},limit={kind='Hinge',axis={0,1,0},lower=0,upper=math.pi}}}}, {-1,0,0}, {iterations=3,tolerance=1e-5})
assert(hingedHalfTurn.error < 1e-5, 'hinge must resolve antiparallel target about the permitted axis')
local one={root={0,0,0},joints={{rest=identity,rotation=identity,offset={1,0,0}}}}
local capped=solver.solve(one,{0,1,0},{iterations=1,tolerance=0,maxStep=math.pi/6})
near(capped.endpoint[1],math.cos(math.pi/6),1e-6)
near(capped.endpoint[2],math.sin(math.pi/6),1e-6)
local cappedHinge=solver.solve(single,{0,1,0},{iterations=1,tolerance=0,maxStep=math.pi/6})
near(cappedHinge.endpoint[2],0.5,1e-6)
local cappedLimited=solver.solve(single,{0,1,0},{iterations=10,tolerance=0,maxStep=math.pi/6})
near(cappedLimited.endpoint[2],math.sqrt(.5),1e-6)
assert(not pcall(function() solver.solve(one,{0,1,0},{iterations=1,tolerance=0,maxStep=0}) end))
assert(not pcall(function() solver.solve(one,{0,1,0},{iterations=1,tolerance=0,maxStep=math.huge}) end))
local rotatedRest = {0,0,math.sin(math.pi/4),math.cos(math.pi/4)}
local restChain = {root={2,3,0},joints={{rest=rotatedRest,rotation=identity,offset={1,0,0},limit={kind='Hinge',axis={0,0,1},lower=-math.pi/2,upper=math.pi/2}}}}
local rotated = solver.solve(restChain, {1,3,0}, {iterations=5,tolerance=1e-6})
assert(rotated.error < 1e-6, 'local hinge axis must respect rest orientation and root translation')
local unreachable = solver.solve(chain(), {4,0,0}, {iterations=8,tolerance=1e-4})
assert(not unreachable.converged and unreachable.iterations == 8)
near(unreachable.error,2,1e-6)
assert(not pcall(function() solver.solve({root={0,0,0},joints={{rest=identity,rotation=identity,offset={0,0,0}}}}, {1,0,0}, {iterations=2,tolerance=0}) end))

print('solver tests passed')
