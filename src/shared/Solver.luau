--!strict
-- Experimental CCD position solver. Vectors are {x,y,z}, quaternions are
-- {x,y,z,w}. Each offset is in the joint's rotated local frame; `rest` is
-- relative to the parent's rotated frame. Rotations are relative to rest.
local Solver = {}
local EPS = 1e-10
local function add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
local function sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
local function length(a) return math.sqrt(dot(a,a)) end
local function scale(a,n) return {a[1]*n,a[2]*n,a[3]*n} end
local function quat(a,b)
 local x,y,z,w=a[1],a[2],a[3],a[4]; local X,Y,Z,W=b[1],b[2],b[3],b[4]
 return {w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z}
end
local function inverse(q) return {-q[1],-q[2],-q[3],q[4]} end
local function normalize(q)
 local n=math.sqrt(q[1]^2+q[2]^2+q[3]^2+q[4]^2)
 assert(n>EPS and n<math.huge,'invalid quaternion')
 return {q[1]/n,q[2]/n,q[3]/n,q[4]/n}
end
local function rotate(q,v)
 local u={q[1],q[2],q[3]}; local t=scale(cross(u,v),2)
 return add(v,add(scale(t,q[4]),cross(u,t)))
end
local function finiteVector(v)
 if type(v)~='table' then return false end
 for i=1,3 do if type(v[i])~='number' or v[i]~=v[i] or math.abs(v[i])==math.huge then return false end end
 return true
end
local function between(a,b)
 local na,nb=length(a),length(b)
 if na<EPS or nb<EPS then return nil end
 a,b=scale(a,1/na),scale(b,1/nb)
 local d=math.clamp(dot(a,b),-1,1)
 if d>1-EPS then return nil end
 if d< -1+EPS then
  local basis=if math.abs(a[1])<0.8 then {1,0,0} else {0,1,0}
  local axis=cross(a,basis); axis=scale(axis,1/length(axis))
  return {axis[1],axis[2],axis[3],0}
 end
 local axis=cross(a,b)
 return normalize({axis[1],axis[2],axis[3],1+d})
end
local function hingeDelta(axis, a, b)
 assert(finiteVector(axis) and length(axis)>EPS, 'invalid hinge axis')
 axis=scale(axis,1/length(axis))
 a=sub(a,scale(axis,dot(axis,a))); b=sub(b,scale(axis,dot(axis,b)))
 if length(a)<EPS or length(b)<EPS then return nil end
 local angle=math.atan2(dot(axis,cross(a,b)),dot(a,b))
 if math.abs(angle)<EPS then return nil end
 local half=angle/2; local sn=math.sin(half)
 return {axis[1]*sn,axis[2]*sn,axis[3]*sn,math.cos(half)}
end
local function forward(root,joints,rotations)
 local positions,bases={},{}
 local pos={root[1],root[2],root[3]}; local orientation={0,0,0,1}
 for i,j in ipairs(joints) do
  positions[i]=pos
  local base=normalize(quat(orientation,normalize(j.rest)))
  bases[i]=base
  orientation=normalize(quat(base,rotations[i]))
  pos=add(pos,rotate(orientation,j.offset))
 end
 return positions,bases,pos
end
function Solver.new(limits)
 assert(type(limits)=='table' and type(limits.hinge)=='function' and type(limits.ball)=='function','limit functions required')
 local api={}
 local function constrain(rotation,limit)
  if not limit then return rotation end
  if limit.kind=='Hinge' then return limits.hinge(rotation,limit.axis,limit.lower,limit.upper) end
  if limit.kind=='Ball' then return limits.ball(rotation,limit.axis,limit.swing,limit.lower,limit.upper) end
  error('unknown limit kind')
 end
 function api.solve(chain,target,options)
  assert(type(chain)=='table' and finiteVector(chain.root) and type(chain.joints)=='table' and #chain.joints>0,'invalid chain')
  assert(finiteVector(target),'invalid target')
  assert(type(options)=='table' and type(options.iterations)=='number' and options.iterations%1==0 and options.iterations>=1 and options.iterations<=1000,'invalid iterations')
  assert(type(options.tolerance)=='number' and options.tolerance==options.tolerance and options.tolerance>=0 and options.tolerance<math.huge,'invalid tolerance')
  local maxStep=if options.maxStep==nil then math.pi else options.maxStep
  assert(type(maxStep)=='number' and maxStep==maxStep and maxStep>0 and maxStep<=math.pi,'invalid maximum correction angle')
  local rotations={}
  for i,j in ipairs(chain.joints) do
   assert(finiteVector(j.offset) and length(j.offset)>EPS,'invalid or zero-length offset')
   normalize(j.rest)
   rotations[i]=constrain(normalize(j.rotation),j.limit)
  end
  local count=0
  local _,_,endpoint=forward(chain.root,chain.joints,rotations)
  while count<options.iterations and length(sub(target,endpoint))>options.tolerance do
   count+=1
   for i=#chain.joints,1,-1 do
    local positions,bases,endPos=forward(chain.root,chain.joints,rotations)
    local from=sub(endPos,positions[i]); local to=sub(target,positions[i])
    local limit=chain.joints[i].limit
    local localDelta
    if limit and limit.kind=='Hinge' then
     localDelta=hingeDelta(limit.axis,rotate(inverse(bases[i]),from),rotate(inverse(bases[i]),to))
    else
     local change=between(from,to)
     if change then localDelta=quat(quat(inverse(bases[i]),change),bases[i]) end
    end
    if localDelta then
     localDelta=normalize(localDelta)
     local magnitude=math.sqrt(localDelta[1]^2+localDelta[2]^2+localDelta[3]^2)
     local angle=2*math.atan2(magnitude,localDelta[4])
     if angle>maxStep and magnitude>EPS then
      local s=math.sin(maxStep/2)/magnitude
      localDelta={localDelta[1]*s,localDelta[2]*s,localDelta[3]*s,math.cos(maxStep/2)}
     end
     local rotation=normalize(quat(localDelta,rotations[i]))
     rotations[i]=constrain(rotation,limit)
    end
   end
   _,_,endpoint=forward(chain.root,chain.joints,rotations)
  end
  local err=length(sub(target,endpoint))
  return {rotations=rotations,endpoint=endpoint,error=err,iterations=count,converged=err<=options.tolerance}
 end
 return api
end
return Solver
