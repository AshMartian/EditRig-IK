--!strict
-- Explicitly stepped world-space target motion for an existing IKControl.
local TargetStepper={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function vector(v)
 assert(typeof(v)=='Vector3' and finite(v.X) and finite(v.Y) and finite(v.Z),'expected a finite Vector3')
 return {v.X,v.Y,v.Z}
end
function TargetStepper.new(target,options,trajectory)
 assert(typeof(target)=='Instance' and (target:IsA('BasePart') or target:IsA('Attachment')) and target.Parent,'target must be a parented BasePart or Attachment')
 assert(not target:IsA('BasePart') or target.Anchored,'target part must be anchored')
 assert(type(options)=='table' and options.exclusive==true and options.ownership,'explicit exclusive ownership required')
 assert(type(trajectory)=='table' and type(trajectory.new)=='function','trajectory factory required')
 local parent=target.Parent
 local function world() return if target:IsA('Attachment') then target.WorldPosition else target.Position end
 local function setWorld(p) if target:IsA('Attachment') then target.WorldPosition=p else target.Position=p end end
 local current=world()
 local setup={start=vector(current),target=vector(current),up=vector(options.up),height=options.height,duration=options.duration}
 trajectory.new(setup) -- validate before acquiring ownership
 local release=options.ownership:acquire({target})
 local lastPosition=target.Position
 local duration,height,up=options.duration,options.height,setup.up
 local active,elapsed=nil,0
 local dead=false
 local function check()
  assert(not dead,'target stepper is destroyed')
  assert(target.Parent==parent and (not target:IsA('BasePart') or target.Anchored),'target was reparented or unanchored')
  assert((target.Position-lastPosition).Magnitude<1e-5,'target changed by another writer')
 end
 local api={}
 function api:requestStep(goal)
  check()
  local swing=trajectory.new({start=vector(world()),target=vector(goal),up=up,height=height,duration=duration})
  active=swing; elapsed=0
 end
 function api:step(dt)
  check()
  assert(finite(dt) and dt>=0,'invalid delta time')
  if not active then return {position=world(),moving=false,progress=1} end
  local nextElapsed=math.min(duration,elapsed+dt)
  local point,done,progress=active:sample(nextElapsed)
  local p=Vector3.new(point[1],point[2],point[3])
  setWorld(p)
  lastPosition=target.Position; elapsed=nextElapsed
  if done then active=nil end
  return {position=p,moving=not done,progress=progress}
 end
 function api:destroy()
  if dead then return end
  dead=true; active=nil; release()
 end
 return api
end
return TargetStepper
