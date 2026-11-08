local SurfaceFrame = require('../src/runtime/SurfaceFrame')
local function near(a,b) assert(math.abs(a-b)<1e-6, tostring(a)..' ~= '..tostring(b)) end
local function vnear(a,b) for i=1,3 do near(a[i],b[i]) end end
local function rotate(q,v)
 local x,y,z,w=q[1],q[2],q[3],q[4]
 local tx,ty,tz=2*(y*v[3]-z*v[2]),2*(z*v[1]-x*v[3]),2*(x*v[2]-y*v[1])
 return {v[1]+w*tx+y*tz-z*ty,v[2]+w*ty+z*tx-x*tz,v[3]+w*tz+x*ty-y*tx}
end
local function opts() return {rotation={0,0,0,1},soleUp={0,1,0},soleForward={0,0,-1},normal={0,1,0}} end
local flat=assert(SurfaceFrame.align(opts()))
vnear(rotate(flat.rotation,{0,1,0}),{0,1,0}); vnear(rotate(flat.rotation,{0,0,-1}),{0,0,-1}); assert(not flat.usedFallback)
local incline=opts(); incline.normal={0,1,1}
local aligned=assert(SurfaceFrame.align(incline))
vnear(rotate(aligned.rotation,incline.soleUp),{0,math.sqrt(.5),math.sqrt(.5)})
vnear(rotate(aligned.rotation,incline.soleForward),{0,math.sqrt(.5),-math.sqrt(.5)})
local rotated=opts(); rotated.rotation={0,math.sqrt(.5),0,math.sqrt(.5)}
local yaw=assert(SurfaceFrame.align(rotated)); vnear(rotate(yaw.rotation,rotated.soleForward),{-1,0,0})
local alternate=opts(); alternate.soleUp={1,0,0}; alternate.soleForward={0,1,0}; alternate.normal={0,1,0}
local arbitrary=assert(SurfaceFrame.align(alternate))
vnear(rotate(arbitrary.rotation,alternate.soleUp),{0,1,0}); vnear(rotate(arbitrary.rotation,alternate.soleForward),{-1,0,0}); assert(arbitrary.usedFallback)
local degenerate=opts(); degenerate.normal={0,0,-1}
local fallback=assert(SurfaceFrame.align(degenerate)); assert(fallback.usedFallback)
vnear(rotate(fallback.rotation,degenerate.soleUp),{0,0,-1}); vnear(rotate(fallback.rotation,degenerate.soleForward),{0,-1,0})
-- Half-turn branches and arbitrary local frames must still map configured axes.
local upside=opts(); upside.normal={0,-1,0}
local turn=assert(SurfaceFrame.align(upside))
vnear(rotate(turn.rotation,upside.soleUp),{0,-1,0}); vnear(rotate(turn.rotation,upside.soleForward),{0,0,-1})
local noisy=opts(); noisy.soleForward={0,0.25,-2}; noisy.normal={1,2,3}
local frame=assert(SurfaceFrame.align(noisy))
vnear(rotate(frame.rotation,{0,1,0}),frame.up); vnear(rotate(frame.rotation,{0,0,-1}),frame.forward)
near(frame.up[1]*frame.forward[1]+frame.up[2]*frame.forward[2]+frame.up[3]*frame.forward[3],0)
assert(frame.rotation[4]>=0,'quaternion sign must remain closest to the input')
for _,change in ipairs({
 function(o) o.normal={0,0,0} end,
 function(o) o.soleUp={0,0,0} end,
 function(o) o.soleForward={0,1,0} end,
 function(o) o.soleForward={0,0,0} end,
 function(o) o.rotation={0,0,0,0} end,
 function(o) o.rotation={0,0,0,math.huge} end,
 function(o) o.normal={0/0,1,0} end,
}) do local o=opts(); change(o); local result, reason=SurfaceFrame.align(o); assert(result==nil and type(reason)=='string','invalid inputs must be diagnosed') end
print('surface frame tests passed')
