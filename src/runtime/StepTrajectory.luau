--!strict
-- Time-based swing target; no raycasting, gait scheduling or rig ownership.
local StepTrajectory={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function vector(v)
 assert(type(v)=='table' and finite(v[1]) and finite(v[2]) and finite(v[3]),'expected a finite three-number vector')
 return {v[1],v[2],v[3]}
end
function StepTrajectory.new(options)
 assert(type(options)=='table','step options required')
 local start,target,up=vector(options.start),vector(options.target),vector(options.up)
 local length=math.sqrt(up[1]^2+up[2]^2+up[3]^2)
 assert(length>1e-10 and length<math.huge,'up direction must be nonzero and finite')
 assert(finite(options.height) and options.height>=0,'height must be finite and nonnegative')
 assert(finite(options.duration) and options.duration>0,'duration must be finite and positive')
 for i=1,3 do up[i]/=length end
 local height,duration,elapsed=options.height,options.duration,0
 local api={}
 function api:sample(time)
  assert(finite(time) and time>=0,'time must be finite and nonnegative')
  local t=math.clamp(time/duration,0,1)
  local blend=t*t*(3-2*t)
  local lift=16*t*t*(1-t)*(1-t)*height
  local point={}
  for i=1,3 do point[i]=start[i]*(1-blend)+target[i]*blend+up[i]*lift end
  return point,t>=1,t
 end
 function api:advance(dt)
  assert(finite(dt) and dt>=0,'delta time must be finite and nonnegative')
  elapsed=math.min(duration,elapsed+dt)
  return self:sample(elapsed)
 end
 return api
end
return StepTrajectory
