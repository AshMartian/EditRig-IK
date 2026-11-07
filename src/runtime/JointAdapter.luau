--!strict
-- Explicitly owned Motor6D/Bone transforms. Caller schedules updates and resolves
-- Animator/IKControl ownership; this module does not disable other writers.
local JointAdapter = {}
local function finite(n)
 return type(n)=='number' and n==n and math.abs(n)<math.huge
end
function JointAdapter.new(bindings, options, limits)
 assert(type(options)=='table' and options.exclusive==true, 'explicit exclusive ownership is required')
 local baseMode=if options.baseMode==nil then 'fixed' else options.baseMode
 assert(baseMode=='fixed' or baseMode=='animated','baseMode must be fixed or animated')
 local limitMode=if options.limitMode==nil then 'offset' else options.limitMode
 assert(limitMode=='offset' or limitMode=='absolute','limitMode must be offset or absolute')
 if limitMode=='absolute' then assert(type(limits)=='table' and type(limits.hinge)=='function' and type(limits.ball)=='function','absolute limits require limit functions') end
 assert(type(bindings)=='table' and #bindings>0, 'joint bindings required')
 local entries,names,instances={},{},{}
 for _,b in ipairs(bindings) do
  assert(type(b.name)=='string' and b.name~='' and not names[b.name], 'invalid or duplicate binding name')
  assert(typeof(b.joint)=='Instance' and (b.joint:IsA('Motor6D') or b.joint:IsA('Bone')) and not instances[b.joint], 'expected distinct Motor6D or Bone')
  assert(typeof(b.axis)=='Vector3' and finite(b.axis.X) and finite(b.axis.Y) and finite(b.axis.Z) and b.axis.Magnitude>1e-8, 'invalid joint axis')
  local kind=if b.kind==nil then 'Hinge' else b.kind
  assert(kind=='Hinge' or kind=='Ball','invalid binding kind')
  local axis=b.axis.Unit
  local limit=nil
  if limitMode=='absolute' then
   assert(type(b.limit)=='table','absolute limit settings required for '..b.name)
   limit={axis={axis.X,axis.Y,axis.Z},lower=b.limit.lower,upper=b.limit.upper,swing=b.limit.swing}
   if kind=='Hinge' then limits.hinge({0,0,0,1},limit.axis,limit.lower,limit.upper)
   else limits.ball({0,0,0,1},limit.axis,limit.swing,limit.lower,limit.upper) end
  end
  local entry={name=b.name,joint=b.joint,parent=b.joint.Parent,axis=axis,kind=kind,limit=limit,original=b.joint.Transform,base=b.joint.Transform,last=b.joint.Transform,written=false}
  names[b.name]=true; instances[b.joint]=true; table.insert(entries,entry)
 end
 local release=if options.ownership then options.ownership:acquire((function() local joints={} for _,e in ipairs(entries) do table.insert(joints,e.joint) end return joints end)()) else function() end
 local dead=false
 local api={}
 function api:validate()
  assert(not dead, 'adapter is destroyed')
  for _,e in ipairs(entries) do
   assert(e.joint.Parent==e.parent,'joint was reparented: '..e.name)
   if baseMode=='fixed' then assert(e.joint.Transform:FuzzyEq(e.last,1e-5), 'transform changed by another writer: '..e.name) end
  end
 end
 function api:apply(angles)
  self:validate()
  assert(type(angles)=='table','angles must be a table')
  local targets,bases={},{}
  for i,e in ipairs(entries) do
   local current=e.joint.Transform
   local base=if baseMode=='fixed' then e.original elseif e.written and current:FuzzyEq(e.last,1e-5) then e.base else current
   bases[i]=base
   local value=angles[e.name]
   if e.kind=='Hinge' then
    assert(finite(value), 'missing or invalid angle for '..e.name)
    targets[i]=base*CFrame.fromAxisAngle(e.axis,value)
   else
    assert(type(value)=='table' and #value==4 and finite(value[1]) and finite(value[2]) and finite(value[3]) and finite(value[4]),'missing or invalid rotation for '..e.name)
    local magnitude=math.sqrt(value[1]^2+value[2]^2+value[3]^2+value[4]^2)
    assert(magnitude>1e-12 and magnitude<math.huge,'invalid rotation for '..e.name)
    targets[i]=base*CFrame.new(0,0,0,value[1]/magnitude,value[2]/magnitude,value[3]/magnitude,value[4]/magnitude)
   end
   if limitMode=='absolute' then
    local axis,angle=targets[i].Rotation:ToAxisAngle()
    local half=angle/2; local sinHalf=math.sin(half)
    local q={axis.X*sinHalf,axis.Y*sinHalf,axis.Z*sinHalf,math.cos(half)}
    local limit=e.limit
    local constrained=if e.kind=='Hinge' then limits.hinge(q,limit.axis,limit.lower,limit.upper) else limits.ball(q,limit.axis,limit.swing,limit.lower,limit.upper)
    targets[i]=CFrame.new(targets[i].Position)*CFrame.new(0,0,0,constrained[1],constrained[2],constrained[3],constrained[4])
   end
  end
  for i,e in ipairs(entries) do
   e.joint.Transform=targets[i]
   e.base=bases[i]; e.last=e.joint.Transform; e.written=true
  end
 end
 function api:destroy()
  if dead then return {} end
  dead=true
  local conflicts={}
  local ok,err=pcall(function()
   for _,e in ipairs(entries) do
    if e.written then
     if e.joint.Transform:FuzzyEq(e.last,1e-5) then e.joint.Transform=if baseMode=='animated' then e.base else e.original else table.insert(conflicts,e.name) end
    end
   end
  end)
  release()
  if not ok then error(err) end
  return conflicts
 end
 return api
end
return JointAdapter
