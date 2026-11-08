--!strict
-- A geometric target, not a joint-limited orientation solve. Vectors use xyz;
-- rotations use xyzw. The caller owns support transitions and smoothing.
local SurfaceFrame = {}
local function finite(n)
 return type(n)=='number' and n==n and math.abs(n)<math.huge
end
local function vector(v,n)
 if type(v)~='table' then return nil end
 local a={}
 for i=1,n do if not finite(v[i]) then return nil end; a[i]=v[i] end
 return a
end
local function unit(v)
 local m=0
 for _,n in ipairs(v) do m+=n*n end
 m=math.sqrt(m)
 if not finite(m) or m<1e-10 then return nil end
 local r={}; for i,n in ipairs(v) do r[i]=n/m end; return r
end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function tangent(v,n)
 local d=dot(v,n)
 return unit({v[1]-d*n[1],v[2]-d*n[2],v[3]-d*n[3]})
end
local function rotate(q,v)
 local t=cross(q,v); t={2*t[1],2*t[2],2*t[3]}; local c=cross(q,t)
 return {v[1]+q[4]*t[1]+c[1],v[2]+q[4]*t[2]+c[2],v[3]+q[4]*t[3]+c[3]}
end
-- Convert a proper 3x3 rotation matrix to a quaternion, selecting the largest
-- diagonal branch to avoid dividing by a small number near a half-turn.
local function quaternion(m)
 local trace=m[1][1]+m[2][2]+m[3][3]
 local x,y,z,w
 if trace>0 then
  local s=math.sqrt(trace+1)*2; w=s/4; x=(m[3][2]-m[2][3])/s; y=(m[1][3]-m[3][1])/s; z=(m[2][1]-m[1][2])/s
 elseif m[1][1]>m[2][2] and m[1][1]>m[3][3] then
  local s=math.sqrt(1+m[1][1]-m[2][2]-m[3][3])*2; w=(m[3][2]-m[2][3])/s; x=s/4; y=(m[1][2]+m[2][1])/s; z=(m[1][3]+m[3][1])/s
 elseif m[2][2]>m[3][3] then
  local s=math.sqrt(1+m[2][2]-m[1][1]-m[3][3])*2; w=(m[1][3]-m[3][1])/s; x=(m[1][2]+m[2][1])/s; y=s/4; z=(m[2][3]+m[3][2])/s
 else
  local s=math.sqrt(1+m[3][3]-m[1][1]-m[2][2])*2; w=(m[2][1]-m[1][2])/s; x=(m[1][3]+m[3][1])/s; y=(m[2][3]+m[3][2])/s; z=s/4
 end
 return unit({x,y,z,w})
end
function SurfaceFrame.align(options)
 if type(options)~='table' then return nil,'invalid surface frame options' end
 local rv=vector(options.rotation,4); local uv=vector(options.soleUp,3); local fv=vector(options.soleForward,3); local nv=vector(options.normal,3)
 local rotation=rv and unit(rv); local up=uv and unit(uv); local forward=fv and unit(fv); local normal=nv and unit(nv)
 if not rotation or not up or not forward or not normal then return nil,'invalid rotation or axis' end
 -- A supplied forward can have a small up component: project it to the sole
 -- plane, but reject parallel axes because they cannot specify heading.
 local localForward=tangent(forward,up)
 if not localForward then return nil,'sole up and forward axes are parallel' end
 local localRight=cross(localForward,up)
 local worldForward=tangent(rotate(rotation,localForward),normal)
 local usedFallback=worldForward==nil
 if usedFallback then
  local worldRight=tangent(rotate(rotation,localRight),normal)
  if not worldRight then return nil,'cannot determine surface heading' end
  worldForward=unit(cross(normal,worldRight))
 end
 local worldRight=cross(worldForward,normal)
 -- R = [right, up, -forward]_world * transpose([right, up, -forward]_local).
 local m={}
 for row=1,3 do
  m[row]={}
  for col=1,3 do
   m[row][col]=worldRight[row]*localRight[col]+normal[row]*up[col]+worldForward[row]*localForward[col]
  end
 end
 local output=quaternion(m)
 if not output then return nil,'invalid surface rotation' end
 -- Equivalent quaternion signs represent the same rotation. Choose the one
 -- nearest the input so simple downstream interpolation does not take a detour.
 local d=0; for i=1,4 do d+=output[i]*rotation[i] end
 if d<0 then for i=1,4 do output[i]=-output[i] end end
 return {rotation=output,up=normal,forward=worldForward,usedFallback=usedFallback}
end
return SurfaceFrame
