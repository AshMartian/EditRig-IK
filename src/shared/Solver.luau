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
  local gain=if options.gain==nil then 1 else options.gain
  assert(type(gain)=='number' and gain==gain and gain>0 and gain<=1,'invalid correction gain')
  assert(options.pole==nil or finiteVector(options.pole),'invalid pole')
  local rotations={}
  local hasReach=false
  for i,j in ipairs(chain.joints) do
   assert(finiteVector(j.offset),'invalid offset')
   if length(j.offset)>EPS then hasReach=true end
   normalize(j.rest)
   rotations[i]=constrain(normalize(j.rotation),j.limit)
  end
  assert(hasReach,'chain has no nonzero links')
  local count=0
  local _,_,endpoint=forward(chain.root,chain.joints,rotations)
  -- A collinear shortened target gives CCD no bend direction. Seed a small
  -- root rotation toward the pole, subject to the same root limit and budget.
  if options.pole and #chain.joints>1 and length(sub(target,endpoint))>options.tolerance then
   local positions,bases=forward(chain.root,chain.joints,rotations)
   local direction=sub(target,positions[1]); local distance=length(direction)
   if distance>EPS then
    local axis=scale(direction,1/distance)
    local endVector=sub(endpoint,positions[1])
    local bend=sub(positions[2],positions[1]); bend=sub(bend,scale(axis,dot(bend,axis)))
    local endSide=sub(endVector,scale(axis,dot(endVector,axis)))
    local desired=sub(options.pole,positions[1]); desired=sub(desired,scale(axis,dot(desired,axis)))
    local straightTolerance=1e-6*math.max(1,distance,length(endVector))
    if length(bend)<straightTolerance and length(endSide)<straightTolerance and dot(endVector,axis)>distance and length(desired)>straightTolerance then
     local turn=cross(axis,desired); turn=scale(turn,1/length(turn))
     local half=math.min(maxStep,0.1*gain)/2; local s=math.sin(half)
     local worldDelta={turn[1]*s,turn[2]*s,turn[3]*s,math.cos(half)}
     local localDelta=quat(quat(inverse(bases[1]),worldDelta),bases[1])
     rotations[1]=constrain(normalize(quat(localDelta,rotations[1])),chain.joints[1].limit)
     _,_,endpoint=forward(chain.root,chain.joints,rotations)
    end
   end
  end
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
     local corrected=math.min(angle*gain,maxStep)
     if corrected<angle and magnitude>EPS then
      local s=math.sin(corrected/2)/magnitude
      localDelta={localDelta[1]*s,localDelta[2]*s,localDelta[3]*s,math.cos(corrected/2)}
     end
     local rotation=normalize(quat(localDelta,rotations[i]))
     rotations[i]=constrain(rotation,limit)
    end
   end
   _,_,endpoint=forward(chain.root,chain.joints,rotations)
  end
  local poleStatus=if options.pole then 'degenerate' else 'none'
  if options.pole and #chain.joints>1 then
   local positions,bases=forward(chain.root,chain.joints,rotations)
   local axis=sub(endpoint,positions[1]); local axisLength=length(axis)
   if axisLength>EPS then
    axis=scale(axis,1/axisLength)
    local bend=sub(positions[2],positions[1]); bend=sub(bend,scale(axis,dot(bend,axis)))
    local desired=sub(options.pole,positions[1]); desired=sub(desired,scale(axis,dot(desired,axis)))
    if length(bend)>EPS and length(desired)>EPS then
     local angle=math.atan2(dot(axis,cross(bend,desired)),dot(bend,desired))
     if math.abs(angle)<=EPS then poleStatus='aligned' else
      angle=math.clamp(angle*gain,-maxStep,maxStep)
      local half=angle/2; local s=math.sin(half)
      local worldDelta={axis[1]*s,axis[2]*s,axis[3]*s,math.cos(half)}
      local localDelta=quat(quat(inverse(bases[1]),worldDelta),bases[1])
      local original=rotations[1]
      rotations[1]=constrain(normalize(quat(localDelta,original)),chain.joints[1].limit)
      local _,_,candidate=forward(chain.root,chain.joints,rotations)
      local similarity=math.abs(original[1]*rotations[1][1]+original[2]*rotations[1][2]+original[3]*rotations[1][3]+original[4]*rotations[1][4])
      if similarity<1-1e-10 and length(sub(target,candidate))<=length(sub(target,endpoint))+1e-8 then
       endpoint=candidate; poleStatus='applied'
      else rotations[1]=original; poleStatus='blocked' end
     end
    end
   end
  end
  local err=length(sub(target,endpoint))
  return {rotations=rotations,endpoint=endpoint,error=err,iterations=count,converged=err<=options.tolerance,poleStatus=poleStatus}
 end
 return api
end
return Solver
