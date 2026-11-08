--!strict
-- Engine-independent contact observation. A hit is not proof of planted support.
local SurfaceContact = {}
local function finite(x)
 return type(x)=='number' and x==x and math.abs(x)<math.huge
end
local function vector(v)
 if type(v)~='table' or not finite(v[1]) or not finite(v[2]) or not finite(v[3]) then return nil end
 return {v[1],v[2],v[3]}
end
local function unit(v)
 local n=math.sqrt(v[1]*v[1]+v[2]*v[2]+v[3]*v[3])
 if not finite(n) or n<1e-10 then return nil end
 return {v[1]/n,v[2]/n,v[3]/n}
end
function SurfaceContact.probe(options, cast)
 assert(type(options)=='table' and type(cast)=='function','contact options and cast function required')
 local origin=vector(options.origin)
 local rawDirection=vector(options.direction)
 local rawUp=vector(options.up)
 local direction=rawDirection and unit(rawDirection)
 local up=rawUp and unit(rawUp)
 assert(origin and direction and up,'origin and nonzero finite direction and up are required')
 assert(finite(options.distance) and options.distance>0,'probe distance must be finite and positive')
 assert(finite(options.maxSlopeDegrees) and options.maxSlopeDegrees>=0 and options.maxSlopeDegrees<=90,'maximum slope must be 0–90 degrees')
 assert(finite(options.soleOffset),'sole offset must be finite')
 assert(type(options.supporting)=='boolean','explicit supporting state required')
 local delta={direction[1]*options.distance,direction[2]*options.distance,direction[3]*options.distance}
 local hit=cast(origin,delta)
 if hit==nil then return {status='no contact',supporting=false} end
 if type(hit)~='table' then return {status='invalid contact',supporting=false} end
 local position=vector(hit.position)
 local rawNormal=vector(hit.normal)
 local normal=rawNormal and unit(rawNormal)
 if not position or not normal then return {status='invalid contact',supporting=false} end
 local dot=math.clamp(normal[1]*up[1]+normal[2]*up[2]+normal[3]*up[3],-1,1)
 local slope=math.deg(math.acos(dot))
 local result={status='excluded slope',supporting=false,position=position,normal=normal,slopeDegrees=slope,instance=hit.instance}
 if slope>options.maxSlopeDegrees+1e-9 then return result end
 result.status='contact'
 result.supporting=options.supporting
 result.target={position[1]+normal[1]*options.soleOffset,position[2]+normal[2]*options.soleOffset,position[3]+normal[3]*options.soleOffset}
 if not vector(result.target) then return {status='invalid contact',supporting=false} end
 return result
end
return SurfaceContact
