--!strict
-- Actor behavior that turns named vector impulses into one swing target.
local Footstep={}
function Footstep.new(options,trajectory)
 assert(type(options)=='table' and type(trajectory)=='table' and type(trajectory.new)=='function','footstep options and trajectory factory required')
 assert(type(options.impulse)=='string' and #options.impulse>0 and #options.impulse<=128,'valid impulse name required')
 local setup={start=options.start,target=options.start,up=options.up,height=options.height,duration=options.duration}
 local initial=trajectory.new(setup)
 local current=initial:sample(0)
 local up={options.up[1],options.up[2],options.up[3]}
 local height,duration,name=options.height,options.duration,options.impulse
 local active=nil
 local behavior={}
 function behavior.step(_,dt,signals)
  assert(type(dt)=='number' and dt==dt and dt>=0 and dt<math.huge,'invalid delta time')
  local nextActive=active
  for _,message in ipairs(signals.impulses) do
   if message.name==name then
    nextActive=trajectory.new({start=current,target=message.value,up=up,height=height,duration=duration})
   end
  end
  local point,done,progress
  if nextActive then point,done,progress=nextActive:advance(dt)
  else point={current[1],current[2],current[3]}; done=true; progress=1 end
  current=point
  active=if done then nil else nextActive
  return {position={point[1],point[2],point[3]},moving=not done,progress=progress}
 end
 return behavior
end
return Footstep
