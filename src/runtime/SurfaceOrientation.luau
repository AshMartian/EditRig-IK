--!strict
-- Converts explicit Roblox frames to the numeric surface-frame geometry.
-- Computes a rotation only; it does not claim joint limits, contact, or ownership.
local SurfaceOrientation = {}
local function finite(n)
 return type(n)=='number' and n==n and math.abs(n)<math.huge
end
local function vector(v)
 assert(typeof(v)=='Vector3' and finite(v.X) and finite(v.Y) and finite(v.Z),'expected a finite Vector3')
 return {v.X,v.Y,v.Z}
end
local function quaternion(cf)
 local _,_,_,m00,m01,m02,m10,m11,m12,m20,m21,m22=cf:GetComponents()
 assert(finite(m00) and finite(m01) and finite(m02) and finite(m10) and finite(m11) and finite(m12) and finite(m20) and finite(m21) and finite(m22),'expected a finite rotation')
 local x,y,z,w
 local trace=m00+m11+m22
 if trace>0 then
  local s=math.sqrt(trace+1)*2; w=.25*s; x=(m21-m12)/s; y=(m02-m20)/s; z=(m10-m01)/s
 elseif m00>m11 and m00>m22 then
  local s=math.sqrt(1+m00-m11-m22)*2; w=(m21-m12)/s; x=.25*s; y=(m01+m10)/s; z=(m02+m20)/s
 elseif m11>m22 then
  local s=math.sqrt(1+m11-m00-m22)*2; w=(m02-m20)/s; x=(m01+m10)/s; y=.25*s; z=(m12+m21)/s
 else
  local s=math.sqrt(1+m22-m00-m11)*2; w=(m10-m01)/s; x=(m02+m20)/s; y=(m12+m21)/s; z=.25*s
 end
 return {x,y,z,w}
end
function SurfaceOrientation.align(current,soleUp,soleForward,normal,strength,surfaceFrame)
 assert(typeof(current)=='CFrame','current orientation must be a CFrame')
 assert(finite(strength) and strength>=0 and strength<=1,'strength must be between 0 and 1')
 assert(type(surfaceFrame)=='table' and type(surfaceFrame.align)=='function','surface frame module required')
 local result,reason=surfaceFrame.align({rotation=quaternion(current),soleUp=vector(soleUp),soleForward=vector(soleForward),normal=vector(normal)})
 if not result then return nil,reason end
 local q=result.rotation
 local target=CFrame.new(0,0,0,q[1],q[2],q[3],q[4])
 return {rotation=current.Rotation:Lerp(target,strength),usedFallback=result.usedFallback}
end
return SurfaceOrientation
