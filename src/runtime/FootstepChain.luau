--!strict
-- Explicitly scheduled footstep target and owned IK chain.
local FootstepChain={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function vector(v)
 assert(typeof(v)=='Vector3' and finite(v.X) and finite(v.Y) and finite(v.Z),'expected a finite Vector3')
 return {v.X,v.Y,v.Z}
end
function FootstepChain.new(options,components)
 assert(type(options)=='table' and options.exclusive==true,'explicit exclusive ownership required')
 assert(type(components)=='table' and components.behavior and components.trajectory and type(components.createChain)=='function','footstep components required')
 local behavior=components.behavior.new({start=vector(options.start),up=vector(options.up),height=options.height,duration=options.duration,impulse='step'},components.trajectory)
 local chain=components.createChain({exclusive=true})
 local pending=nil
 local dead=false
 local api={}
 function api:requestStep(target)
  assert(not dead,'footstep chain is destroyed')
  pending=vector(target)
 end
 function api:step(dt)
  assert(not dead,'footstep chain is destroyed')
  local messages=if pending then {{name='step',value=pending}} else {}
  local output=behavior.step({},dt,{impulses=messages,values={}})
  pending=nil
  local p=output.position
  local target=Vector3.new(p[1],p[2],p[3])
  local result=chain:solve(target)
  return {target=target,moving=output.moving,progress=output.progress,solve=result}
 end
 function api:destroy()
  if dead then return {} end
  dead=true
  return chain:destroy()
 end
 return api
end
return FootstepChain
