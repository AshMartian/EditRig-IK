local Actor=require('../src/runtime/Actor')
local StepTrajectory=require('../src/runtime/StepTrajectory')
local Footstep=require('../src/runtime/FootstepBehavior')
local spec={behaviors={{name='left',type='footstep',options={start={0,0,0},up={0,1,0},height=1,duration=2,impulse='StepLeft'}}}}
local function create() return Actor.new(spec,{footstep=function(options) return Footstep.new(options,StepTrajectory) end}) end
local actor=create()
local function step(dt) return actor:step({},dt)[1].value end
assert(not step(0).moving)
actor:impulse('StepLeft',{2,0,0})
local mid=step(1)
assert(mid.moving and math.abs(mid.position[1]-1)<1e-8 and math.abs(mid.position[2]-1)<1e-8)
actor:impulse('StepLeft',{3,0,0})
local restart=step(0)
assert(restart.moving and math.abs(restart.position[1]-1)<1e-8 and math.abs(restart.position[2]-1)<1e-8,'retarget from current position')
local endPoint=step(2)
assert(not endPoint.moving and endPoint.position[1]==3 and endPoint.position[2]==0)
local independent=create(); assert(independent:step({},0)[1].value.position[1]==0)
independent:impulse('StepLeft',{1,0,0}); independent:impulse('StepLeft',{4,0,0})
local last=independent:step({},2)[1].value
assert(last.position[1]==4 and not last.moving,'last request in a step wins')
last.position[1]=99
assert(independent:step({},0)[1].value.position[1]==4,'outputs must not expose behavior state')
assert(not pcall(function() Footstep.new({start={0,0,0},up={0,1,0},height=1,duration=0,impulse='step'},StepTrajectory) end))
actor:destroy(); independent:destroy()
print('footstep behavior tests passed')
