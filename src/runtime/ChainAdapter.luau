--!strict
-- Explicit, ordered, homogeneous position-only IK chain; no automatic discovery.
local ChainAdapter={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function validVector(v)
 return typeof(v)=='Vector3' and finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function vector(v) return {v.X,v.Y,v.Z} end
local function quaternion(cf)
 local axis,angle=cf.Rotation:ToAxisAngle()
 local s=math.sin(angle/2)
 return {axis.X*s,axis.Y*s,axis.Z*s,math.cos(angle/2)}
end
local function frame(q) return CFrame.new(0,0,0,q[1],q[2],q[3],q[4]) end
function ChainAdapter.new(joints,endpointLocal,options,solver)
 assert(type(options)=='table' and options.exclusive==true,'explicit exclusive ownership required')
 assert(type(joints)=='table' and #joints>0 and validVector(endpointLocal),'joint chain and local endpoint required')
 assert(type(solver)=='table' and type(solver.solve)=='function','solver required')
 local first=joints[1]
 assert(typeof(first)=='Instance' and (first:IsA('Motor6D') or first:IsA('Bone')),'expected Motor6D or Bone chain')
 local kind=first.ClassName
 local entries,seen={},{}
 for i,j in ipairs(joints) do
  assert(typeof(j)=='Instance' and j.ClassName==kind and not seen[j],'chain must contain distinct joints of one type')
  seen[j]=true
  assert(j.Transform.Position.Magnitude<1e-7,'translated joint transforms are not supported')
  local e={joint=j,original=j.Transform,last=j.Transform,written=false,parent=j.Parent}
  if kind=='Motor6D' then
   assert(j.Enabled and j.Part0 and j.Part1 and j.Part0~=j.Part1,'motor must connect distinct parts')
   if i>1 then assert(j.Part0==joints[i-1].Part1,'disconnected motor chain') end
   e.p0=j.Part0; e.p1=j.Part1; e.c0=j.C0; e.c1=j.C1
  else
   assert(j.Parent and (j.Parent:IsA('Bone') or j.Parent:IsA('BasePart')),'bone needs a Bone or BasePart parent')
   if i>1 then assert(j.Parent==joints[i-1],'disconnected bone chain') end
   e.rest=j.CFrame
  end
  entries[i]=e
 end
 local limits=options.limits or {}
 assert(type(limits)=='table','limits must be a table')
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
  for _,e in ipairs(entries) do
   local j=e.joint
   assert(j.Parent==e.parent and j.Transform:FuzzyEq(e.last,1e-5),'joint changed by another writer or reparented')
   if kind=='Motor6D' then
    assert(j.Enabled and j.Part0==e.p0 and j.Part1==e.p1 and j.C0:FuzzyEq(e.c0,1e-5) and j.C1:FuzzyEq(e.c1,1e-5),'motor geometry changed')
   else assert(j.CFrame:FuzzyEq(e.rest,1e-5),'bone geometry changed') end
  end
  local root=rootFrame()
  local relative=root:PointToObjectSpace(target)
  local data={root={0,0,0},joints={}}
  local prevRest=CFrame.identity
  for i,e in ipairs(entries) do
   local nextEntry=entries[i+1]
   local rel
   if kind=='Motor6D' then rel=e.c1:Inverse()*(if nextEntry then nextEntry.c0 else CFrame.new(endpointLocal))
   else rel=if nextEntry then nextEntry.rest else CFrame.new(endpointLocal) end
   table.insert(data.joints,{rest=quaternion(prevRest),rotation=quaternion(e.last),offset=vector(rel.Position),limit=limits[i]})
   prevRest=rel.Rotation
  end
  local result=solver.solve(data,vector(relative),solveOptions)
  local output={}
  for i,q in ipairs(result.rotations) do output[i]=frame(q) end
  for i,e in ipairs(entries) do e.joint.Transform=output[i]; e.last=e.joint.Transform; e.written=true end
  result.endpointWorld=root:PointToWorldSpace(Vector3.new(result.endpoint[1],result.endpoint[2],result.endpoint[3]))
  return result
 end
 function api:destroy()
  if dead then return {} end
  dead=true
  local conflicts={}
  for i,e in ipairs(entries) do
   if e.written then
    if e.joint.Transform:FuzzyEq(e.last,1e-5) then e.joint.Transform=e.original else table.insert(conflicts,i) end
   end
  end
  return conflicts
 end
 return api
end
return ChainAdapter
