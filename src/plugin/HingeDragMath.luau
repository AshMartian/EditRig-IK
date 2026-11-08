--!strict
-- Accumulate the shortest signed pointer movement to avoid jumping at +/-180.
local HingeDragMath={}
local function finite(value) return type(value)=='number' and value==value and math.abs(value)<math.huge end
function HingeDragMath.begin(bound,lower,upper,pointer)
 assert((bound=='lower' or bound=='upper') and finite(lower) and finite(upper) and lower>=-180 and upper<=180 and lower<=upper and finite(pointer),'valid hinge range and pointer required')
 return {bound=bound,lower=lower,upper=upper,pointer=pointer,angle=if bound=='lower' then lower else upper}
end
function HingeDragMath.move(state,pointer)
 assert(finite(pointer),'finite pointer angle required')
 local delta=(pointer-state.pointer+180)%360-180
 state.pointer=pointer
 -- Saturate the accumulated value itself, so movement in the reverse
 -- direction responds immediately after overshooting a bound. This does not
 -- enable wrapped intervals or crossing the +/-180 limit.
 state.angle=math.clamp(state.angle+delta,if state.bound=='lower' then -180 else state.lower,if state.bound=='lower' then state.upper else 180)
 return state.angle
end
function HingeDragMath.beginCircular(bound,start,width,pointer)
 assert((bound=='lower' or bound=='upper') and finite(start) and finite(width) and width>=0 and width<=360 and finite(pointer),'valid circular hinge range and pointer required')
 return {bound=bound,start=(start+180)%360-180,width=width,pointer=pointer}
end
function HingeDragMath.moveCircular(state,pointer)
 assert(finite(pointer),'finite pointer angle required')
 local delta=(pointer-state.pointer+180)%360-180
 state.pointer=pointer
 if state.bound=='lower' then
  local nextWidth=math.clamp(state.width-delta,0,360)
  state.start=(state.start+state.width-nextWidth+180)%360-180
  state.width=nextWidth
 else
  state.width=math.clamp(state.width+delta,0,360)
 end
 return state.start,state.width
end
return HingeDragMath
