local Solver=require('../src/shared/Solver')
local Limits=require('../src/shared/Limits')
local Circular=require('../src/shared/CircularHinge').v1
local radians=math.rad
local function pose(degrees)
 local a=radians(degrees)/2
 return {0,0,math.sin(a),math.cos(a)}
end
local function point(degrees) local a=radians(degrees); return {math.cos(a),math.sin(a),0} end
local function chain(limit,initial)
 return {root={0,0,0},joints={{rest={0,0,0,1},rotation=pose(initial or 0),offset={1,0,0},limit=limit}}}
end
local function limit(start,width)
 return {kind='Hinge',axis={0,0,1},circular={version=1,start=radians(start),width=radians(width)}}
end
local options={iterations=5,tolerance=1e-7}
local solver=Solver.new(Limits,Circular)
local across=solver.solve(chain(limit(150,60),179),point(-179),options)
assert(across.converged,'a target across ±180° inside the interval must remain reachable')
local blocked=solver.solve(chain(limit(150,60),179),point(-100),options)
assert(math.abs(blocked.endpoint[1]-math.cos(radians(-150)))<1e-6 and math.abs(blocked.endpoint[2]-math.sin(radians(-150)))<1e-6,'target outside the circular interval must clamp to its nearest boundary')
assert(#blocked.limitedJoints==1,'clamping reports a limited joint')
local locked=solver.solve(chain(limit(30,0)),point(-90),options)
assert(math.abs(locked.endpoint[1]-math.cos(radians(30)))<1e-6 and math.abs(locked.endpoint[2]-.5)<1e-6,'zero-width interval locks at its start')
local free=solver.solve(chain(limit(30,360)),point(-90),options)
assert(free.converged,'full-width interval allows an entire revolution')
-- The geometrically shortest turn crosses the excluded 60-degree sector.
-- The solver must take the permitted 300-degree path, respecting maxStep.
local longWay=solver.solve(chain(limit(-150,300),-150),point(150),{iterations=20,tolerance=1e-7,maxStep=radians(30)})
assert(longWay.converged,'solver must reach the target by travelling through the permitted arc')
local firstStep=solver.solve(chain(limit(-150,300),-150),point(150),{iterations=1,tolerance=0,maxStep=radians(90)})
assert(math.abs(firstStep.endpoint[1]-math.cos(radians(-60)))<1e-6 and math.abs(firstStep.endpoint[2]-math.sin(radians(-60)))<1e-6,'a large step must not jump across the forbidden arc')
-- Existing animation outside an authored limit is projected before stepping.
local outside=solver.solve(chain(limit(150,60),-100),point(-150),options)
assert(outside.converged and #outside.limitedJoints==1,'an initial pose outside the interval projects to its nearest boundary')
-- Orientation optimization must not jump over the same excluded sector.
local oriented=solver.solve(chain(limit(-150,300),-150),point(150),{iterations=1,tolerance=0,maxStep=radians(90),targetOrientation=pose(150)})
local orientationAngle=math.deg(math.atan2(oriented.endpoint[2],oriented.endpoint[1]))
assert(orientationAngle>=-150.00001 and orientationAngle<=-59.99999,'orientation corrections must also stay inside the permitted arc and step budget')
local legacySolver=Solver.new(Limits)
local linear=legacySolver.solve(chain({kind='Hinge',axis={0,0,1},lower=radians(-150),upper=radians(150)},179),point(179),options)
assert(not linear.converged and math.abs(linear.endpoint[2]-.5)<1e-6,'legacy linear interval must retain its old meaning')
assert(not pcall(legacySolver.solve,chain(limit(150,60)),point(179),options),'missing circular implementation must fail closed')
assert(not pcall(Solver.new(Limits,{hinge=Circular.hinge}).solve,chain(limit(150,60),179),point(179),options),'incomplete circular implementation must fail even when initial pose is already at target')
local future=limit(150,60); future.circular.version=2
assert(not pcall(solver.solve,chain(future),point(179),options),'unknown circular version must fail closed')
local conflict=limit(150,60); conflict.lower=0; conflict.upper=0
assert(not pcall(solver.solve,chain(conflict),point(179),options),'conflicting linear and circular bounds must fail closed')
local ball=limit(150,60); ball.kind='Ball'; ball.swing=1
assert(not pcall(solver.solve,chain(ball),point(179),options),'circular intervals do not silently alter ball limits')
-- Sample varied starts, widths, targets and step budgets. Measure displacement
-- on the interval itself, not the shorter distance around the circle.
math.randomseed(237)
local turn=2*math.pi
for sample=1,1000 do
 local start=math.random()*turn-math.pi
 local width=math.random()*turn
 local current=start+math.random()*width
 local target=math.random()*turn-math.pi
 local maxStep=math.random()*math.pi+1e-6
 local result=solver.solve(chain(limit(math.deg(start),math.deg(width)),math.deg(current)),point(math.deg(target)),{iterations=1,tolerance=0,maxStep=maxStep})
 local final=math.atan2(result.endpoint[2],result.endpoint[1])
 local offset=(final-start)%turn
 if turn-offset<1e-8 then offset=0 end
 assert(offset<=width+1e-8,'sample '..sample..' escaped its allowed arc')
 assert(math.abs(offset-(current-start))<=maxStep+1e-8,'sample '..sample..' crossed the gap or exceeded maxStep')
end
print('circular solver integration passed')
