--!strict
-- Joint-local limit frame. Quaternions use {x,y,z,w}; nil is the legacy identity.
local LimitFrame={}
local axes={X={1,0,0},Y={0,1,0},Z={0,0,1}}
local references={X={0,1,0},Y={0,0,1},Z={1,0,0}}
local function finite(value)
 return type(value)=='number' and value==value and math.abs(value)<math.huge
end
function LimitFrame.normalize(rotation)
 if rotation==nil then return {0,0,0,1} end
 assert(type(rotation)=='table' and #rotation==4,'limit-frame rotation must have four components')
 local maximum=0
 for i=1,4 do
  assert(finite(rotation[i]),'limit-frame rotation must be finite')
  maximum=math.max(maximum,math.abs(rotation[i]))
 end
 assert(maximum>0,'limit-frame rotation must be nonzero')
 -- Scaling before taking a norm avoids overflowing for large finite components.
 local x,y,z,w=rotation[1]/maximum,rotation[2]/maximum,rotation[3]/maximum,rotation[4]/maximum
 local magnitude=math.sqrt(x*x+y*y+z*z+w*w)
 x,y,z,w=x/magnitude,y/magnitude,z/magnitude,w/magnitude
 -- q and -q are the same frame; choose one representation, including half turns.
 if w<0 or (w==0 and (x<0 or (x==0 and (y<0 or (y==0 and z<0))))) then x,y,z,w=-x,-y,-z,-w end
 return {x,y,z,w}
end
local function rotate(q,v)
 local x,y,z,w=q[1],q[2],q[3],q[4]
 local tx=2*(y*v[3]-z*v[2]); local ty=2*(z*v[1]-x*v[3]); local tz=2*(x*v[2]-y*v[1])
 return {v[1]+w*tx+y*tz-z*ty,v[2]+w*ty+z*tx-x*tz,v[3]+w*tz+x*ty-y*tx}
end
function LimitFrame.basis(axis,rotation)
 assert(axes[axis] and references[axis],'limit-frame axis must be X, Y or Z')
 local q=LimitFrame.normalize(rotation)
 local a=rotate(q,axes[axis]); local r=rotate(q,references[axis])
 local tangent={a[2]*r[3]-a[3]*r[2],a[3]*r[1]-a[1]*r[3],a[1]*r[2]-a[2]*r[1]}
 return {axis=a,reference=r,tangent=tangent}
end
-- Radians. A wrapping result cannot be passed directly to the current
-- Limits.hinge/ball; consumers must explicitly support circular intervals.
function LimitFrame.shiftInterval(lower,upper,offset)
 assert(finite(lower) and finite(upper) and lower>=-math.pi and upper<=math.pi and lower<=upper,'invalid base interval')
 assert(finite(offset),'interval offset must be finite')
 local turn=2*math.pi
 local width=upper-lower
 if width==turn then return {lower=-math.pi,upper=math.pi,wraps=false,full=true} end
 local start=(lower+math.pi+offset%turn)%turn-math.pi
 local stop=start+width
 local wraps=stop>math.pi
 if wraps then stop-=turn end
 return {lower=start,upper=stop,wraps=wraps,full=false}
end
return LimitFrame
