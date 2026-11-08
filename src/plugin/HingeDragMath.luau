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
 state.angle+=delta
 return math.clamp(state.angle,if state.bound=='lower' then -180 else state.lower,if state.bound=='lower' then state.upper else 180)
end
return HingeDragMath
