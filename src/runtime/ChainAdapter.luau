--!strict
-- Runtime.createIKChain adapts an ordered set of Motor6Ds or Bones to the
-- shared numerical solver. It does not discover chains or schedule updates;
-- the caller must manage ownership and dispose of the adapter.
local ChainAdapter={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function validVector(v)
 return typeof(v)=='Vector3' and finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function vector(v) return {v.X,v.Y,v.Z} end
local function validFrame(cf)
 if typeof(cf)~='CFrame' then return false end
 for _,v in ipairs({cf:GetComponents()}) do if not finite(v) then return false end end
 return true
end
local function quaternion(cf)
 local _,_,_,m00,m01,m02,m10,m11,m12,m20,m21,m22=cf:GetComponents()
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
local function frame(q) return CFrame.new(0,0,0,q[1],q[2],q[3],q[4]) end
local function circularPosition(cf,limit)
 local axis=Vector3.new(limit.axis[1],limit.axis[2],limit.axis[3]).Unit
 local q=quaternion(cf)
 local angle=2*math.atan2(q[1]*axis.X+q[2]*axis.Y+q[3]*axis.Z,q[4])
 assert(cf.Rotation:FuzzyEq(CFrame.fromAxisAngle(axis,angle),1e-5),'capped circular hinge starts with off-axis rotation')
 local interval=limit.circular
 local turn=2*math.pi
 local position=(angle-interval.start)%turn
 if position>interval.width and turn-position<1e-5 then position=0 end
 assert(position<=interval.width+1e-5,'capped circular hinge starts outside its allowed arc')
 return math.clamp(position,0,interval.width),axis
end
function ChainAdapter.new(joints,endpointLocal,options,solver)
 assert(type(options)=='table' and options.exclusive==true,'explicit exclusive ownership required')
 local baseMode=if options.baseMode==nil then 'fixed' else options.baseMode
 assert(baseMode=='fixed' or baseMode=='animated','baseMode must be fixed or animated')
 assert(type(joints)=='table' and #joints>0 and validVector(endpointLocal),'joint chain and local endpoint required')
 assert(type(solver)=='table' and type(solver.solve)=='function','solver required')
 local first=joints[1]
 assert(typeof(first)=='Instance' and (first:IsA('Motor6D') or first:IsA('Bone')),'expected Motor6D or Bone chain')
 local kind=first.ClassName
 local entries,seen={},{}
 local seenParts={}
 for i,j in ipairs(joints) do
  assert(typeof(j)=='Instance' and j.ClassName==kind and not seen[j],'chain must contain distinct joints of one type')
  seen[j]=true
  assert(j.Transform.Position.Magnitude<1e-7,'translated joint transforms are not supported')
  local e={joint=j,original=j.Transform,base=j.Transform,last=j.Transform,written=false,parent=j.Parent}
  if kind=='Motor6D' then
   assert(j.Enabled and j.Part0 and j.Part1 and j.Part0~=j.Part1,'motor must connect distinct parts')
   if i>1 then assert(j.Part0==joints[i-1].Part1,'disconnected motor chain') else seenParts[j.Part0]=true end
   assert(not seenParts[j.Part1], 'cyclic motor chain')
   seenParts[j.Part1]=true
   e.p0=j.Part0; e.p1=j.Part1; e.c0=j.C0; e.c1=j.C1
  else
   assert(j.Parent and (j.Parent:IsA('Bone') or j.Parent:IsA('BasePart')),'bone needs a Bone or BasePart parent')
   if i>1 then assert(j.Parent==joints[i-1],'disconnected bone chain') end
   e.rest=j.CFrame
  end
  entries[i]=e
 end
 local endpointOrientation=if options.endpointOrientation==nil then CFrame.identity else options.endpointOrientation
 assert(validFrame(endpointOrientation),'endpointOrientation must be a finite CFrame')
 endpointOrientation=endpointOrientation.Rotation
 local limits=options.limits or {}
 assert(type(limits)=='table','limits must be a table')
 local suppliedWeights=options.weights or {}
 assert(type(suppliedWeights)=='table','weights must be a table')
 local weights={}
 for i=1,#entries do
  local value=if suppliedWeights[i]==nil then 1 else suppliedWeights[i]
  assert(finite(value) and value>=0 and value<=1,'joint influence must be between 0 and 1')
  weights[i]=value
 end
 local release=if options.ownership then options.ownership:acquire(joints) else function() end
 local function rootFrame()
  if kind=='Motor6D' then return entries[1].p0.CFrame*entries[1].c0 end
  local parent=entries[1].parent
  return (if parent:IsA('Bone') then parent.TransformedWorldCFrame else parent.CFrame)*entries[1].rest
 end
 local dead=false
 local api={}
 function api:solve(target,solveOptions)
  assert(not dead,'chain is destroyed')
  assert(validVector(target),'target must be a finite Vector3')
  local rotations,bases={},{}
  for i,e in ipairs(entries) do
   local j=e.joint
   assert(j.Parent==e.parent,'joint changed by another writer or reparented')
   local current=j.Transform
   assert(current.Position.Magnitude<1e-7,'translated joint transforms are not supported')
   if baseMode=='fixed' then assert(current:FuzzyEq(e.last,1e-5),'joint changed by another writer or reparented') end
   local fresh=baseMode=='animated' and (not e.written or not current:FuzzyEq(e.last,1e-5))
   rotations[i]=if fresh then current else e.last
   bases[i]=if fresh then current else e.base
   if kind=='Motor6D' then
    assert(j.Enabled and j.Part0==e.p0 and j.Part1==e.p1 and j.C0:FuzzyEq(e.c0,1e-5) and j.C1:FuzzyEq(e.c1,1e-5),'motor geometry changed')
   else assert(j.CFrame:FuzzyEq(e.rest,1e-5),'bone geometry changed') end
  end
  local root=rootFrame()
  local relative=root:PointToObjectSpace(target)
  assert(type(solveOptions)=='table','solver options required')
  local solverOptions=table.clone(solveOptions)
  local requestedOrientation=solverOptions.targetOrientation
  if requestedOrientation~=nil then
   assert(validFrame(requestedOrientation),'targetOrientation must be a finite world-space CFrame')
   solverOptions.targetOrientation=quaternion(root.Rotation:Inverse()*requestedOrientation.Rotation)
  end
  local speed,dt=solverOptions.maxAngularSpeed,solverOptions.dt
  if speed~=nil then
   assert(finite(speed) and speed>0 and finite(dt) and dt>=0 and finite(speed*dt),'speed cap requires positive finite maxAngularSpeed and nonnegative finite dt')
  else assert(dt==nil,'dt requires maxAngularSpeed') end
  solverOptions.maxAngularSpeed=nil; solverOptions.dt=nil
  if solverOptions.pole~=nil then
   assert(validVector(solverOptions.pole),'pole must be a finite world-space Vector3')
   solverOptions.pole=vector(root:PointToObjectSpace(solverOptions.pole))
  end
  local data={root={0,0,0},joints={}}
  local prevRest=CFrame.identity
  for i,e in ipairs(entries) do
   local nextEntry=entries[i+1]
   local rel
   if kind=='Motor6D' then rel=e.c1:Inverse()*(if nextEntry then nextEntry.c0 else CFrame.new(endpointLocal))
   else rel=if nextEntry then nextEntry.rest else CFrame.new(endpointLocal) end
   table.insert(data.joints,{rest=quaternion(prevRest),rotation=quaternion(rotations[i]),offset=vector(rel.Position),limit=limits[i],weight=weights[i]})
   prevRest=rel.Rotation
  end
  solverOptions.endpointOrientation=quaternion(prevRest*endpointOrientation)
  local result=solver.solve(data,vector(relative),solverOptions)
  local output={}
  local motionLimited=false
  for i,q in ipairs(result.rotations) do
   local destination=frame(q)
   if speed then
    local speedStart=if baseMode=='animated' and entries[i].written then entries[i].last else rotations[i]
    local cap=speed*dt
    local limit=limits[i]
    if limit and limit.circular then
     local current,axis=circularPosition(speedStart,limit)
     local target=circularPosition(destination,limit)
     local distance=target-current
     if limit.circular.width==2*math.pi then distance=(distance+math.pi)%(2*math.pi)-math.pi end
     if math.abs(distance)>cap+1e-10 then
      local applied=current+math.clamp(distance,-cap,cap)
      destination=CFrame.fromAxisAngle(axis,limit.circular.start+applied)
      motionLimited=true
     end
    else
     local delta=quaternion(speedStart:Inverse()*destination)
     local angle=2*math.atan2(math.sqrt(delta[1]^2+delta[2]^2+delta[3]^2),math.abs(delta[4]))
     if angle>cap+1e-10 then destination=speedStart:Lerp(destination,cap/angle); motionLimited=true end
    end
   end
   output[i]=destination
  end
  for i,e in ipairs(entries) do e.joint.Transform=output[i]; e.base=bases[i]; e.last=e.joint.Transform; e.written=true; output[i]=e.last end
  if motionLimited then
   result.solverError=result.error; result.solverConverged=result.converged
   local position=Vector3.zero; local orientation=CFrame.identity
   for i,jointData in ipairs(data.joints) do
    orientation=orientation*frame(jointData.rest)*output[i]
    local offset=jointData.offset
    position+=orientation:VectorToWorldSpace(Vector3.new(offset[1],offset[2],offset[3]))
    result.rotations[i]=quaternion(output[i])
   end
   result.endpoint=vector(position); result.error=(relative-position).Magnitude
   local endpointFrame=orientation*prevRest*endpointOrientation
   result.endpointOrientation=quaternion(endpointFrame)
   if requestedOrientation then
    local delta=(root.Rotation*endpointFrame):Inverse()*requestedOrientation.Rotation
    local _,angle=delta:ToAxisAngle()
    result.orientationError=math.abs(angle)
    result.orientationConverged=result.orientationError<=(solverOptions.orientationTolerance or 0.01)
   end
   result.converged=result.error<=solverOptions.tolerance and (not requestedOrientation or result.orientationConverged)
   if result.status~='outsideReach' then result.status=if result.converged then 'converged' else 'notConverged' end
  end
  result.motionLimited=motionLimited
  result.endpointWorld=root:PointToWorldSpace(Vector3.new(result.endpoint[1],result.endpoint[2],result.endpoint[3]))
  result.endpointOrientationWorld=(root.Rotation*frame(result.endpointOrientation)).Rotation
  return result
 end
 function api:destroy()
  if dead then return {} end
  dead=true
  local conflicts={}
  local ok,err=pcall(function()
   for i,e in ipairs(entries) do
    if e.written then
     if e.joint.Transform:FuzzyEq(e.last,1e-5) then e.joint.Transform=if baseMode=='animated' then e.base else e.original else table.insert(conflicts,i) end
    end
   end
  end)
  release()
  if not ok then error(err) end
  return conflicts
 end
 return api
end
return ChainAdapter
