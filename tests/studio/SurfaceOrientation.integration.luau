-- SurfaceFrame and SurfaceOrientation are supplied by the Studio fixture harness.
assert(SurfaceOrientation and SurfaceFrame, 'surface orientation modules required')
local function near(a,b) return (a-b).Magnitude<1e-5 end
local function angle(a,b) local _,n=(a:Inverse()*b):ToAxisAngle(); return math.abs(n) end
local up,forward=Vector3.yAxis,Vector3.new(0,0,-1)
local current=CFrame.new(7,8,9)*CFrame.Angles(0,.7,0)
local normal=Vector3.new(0,1,1).Unit
local full=assert(SurfaceOrientation.align(current,up,forward,normal,1,SurfaceFrame))
assert(full.rotation.Position==Vector3.zero,'result must be rotation-only')
assert(near(full.rotation:VectorToWorldSpace(up),normal),'full strength must align the configured sole up to the surface normal')
local desiredForward=current:VectorToWorldSpace(forward)
desiredForward=(desiredForward-normal*desiredForward:Dot(normal)).Unit
assert(near(full.rotation:VectorToWorldSpace(forward),desiredForward),'full strength must retain the projected world heading')
local zero=assert(SurfaceOrientation.align(current,up,forward,normal,0,SurfaceFrame))
assert(angle(current.Rotation,zero.rotation)<1e-5,'zero strength must retain the current orientation')
local half=assert(SurfaceOrientation.align(current,up,forward,normal,.5,SurfaceFrame))
assert(math.abs(angle(current.Rotation,half.rotation)*2-angle(current.Rotation,full.rotation))<1e-5,'half strength must follow the shortest rotational arc')
-- The injected geometry target straddles the quaternion wrap at 180 degrees.
local wrapStart=CFrame.Angles(0,math.rad(179),0)
local wrapTarget={align=function() local a=math.rad(-179)/2; return {rotation={0,math.sin(a),0,math.cos(a)},usedFallback=false} end}
local wrap=assert(SurfaceOrientation.align(wrapStart,up,forward,up,.5,wrapTarget))
assert(math.abs(angle(wrapStart,wrap.rotation)-math.rad(1))<1e-5,'blend must take the short path across quaternion sign wrap')
local rotated=CFrame.Angles(.4,-1.1,.25)
local nonstandardUp=Vector3.xAxis
local nonstandardForward=Vector3.zAxis
local aligned=assert(SurfaceOrientation.align(rotated,nonstandardUp,nonstandardForward,normal,1,SurfaceFrame))
assert(near(aligned.rotation:VectorToWorldSpace(nonstandardUp),normal),'must use configured sole axes, not assume Y up')
local fallback=assert(SurfaceOrientation.align(CFrame.identity,up,forward,Vector3.new(0,0,-1),1,SurfaceFrame))
assert(fallback.usedFallback and near(fallback.rotation:VectorToWorldSpace(up),Vector3.new(0,0,-1)),'degenerate projected heading must report fallback')
local no,why=SurfaceOrientation.align(current,up,up,normal,1,SurfaceFrame)
assert(no==nil and type(why)=='string','parallel local sole axes must be rejected')
assert(SurfaceOrientation.align(current,up,forward,Vector3.zero,1,SurfaceFrame)==nil,'zero surface normal must be rejected')
for _,bad in ipairs({-0.1,1.1,math.huge,0/0}) do
 assert(not pcall(SurfaceOrientation.align,current,up,forward,normal,bad,SurfaceFrame),'invalid strength must be rejected')
end
return 'Surface orientation adapter respects sole axes, strength, fallback and validation'
