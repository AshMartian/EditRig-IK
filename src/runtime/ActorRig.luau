--!strict
-- Experimental explicit-owner actor built from saved ObjectValue bindings.
local ActorRig={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function ActorRig.new(folder,components,options)
 assert(typeof(folder)=='Instance' and folder:IsA('Folder') and folder.Parent and folder.Parent:IsA('Model'),'actor definition must be a folder in a model')
 assert(folder:GetAttribute('EditRigIK_ActorSchemaVersion')==1, 'unsupported actor definition schema')
 assert(type(components)=='table' and components.Actor and components.JointDrive and components.JointAdapter,'runtime components required')
 options=options or {}
 assert(type(options)=='table' and (options.baseMode==nil or options.baseMode=='fixed' or options.baseMode=='animated'),'invalid actor base mode')
 local refs=folder:GetChildren()
 table.sort(refs,function(a,b) return a.Name<b.Name end)
 local hingeConfigs,ballConfigs,bindings,seen={}, {}, {}, {}
 local controls,impulses={},{}
 local axes={X=Vector3.xAxis,Y=Vector3.yAxis,Z=Vector3.zAxis}
 for _,ref in ipairs(refs) do
  assert(ref:IsA('ObjectValue') and ref.Value and (ref.Value:IsA('Motor6D') or ref.Value:IsA('Bone')), 'definition must contain only joint references')
  assert(ref.Value:IsDescendantOf(folder.Parent),'joint must belong to the actor model')
  assert(ref.Name~='' and not seen[ref.Name], 'joint reference names must be unique')
  seen[ref.Name]=true
  local kind,axis=ref:GetAttribute('Kind'),ref:GetAttribute('Axis')
  local lower,upper=ref:GetAttribute('LowerDegrees'),ref:GetAttribute('UpperDegrees')
  local control,impulse,frequency=ref:GetAttribute('Control'),ref:GetAttribute('Impulse'),ref:GetAttribute('Frequency')
  assert((kind=='Hinge' or kind=='Ball') and axes[axis], 'invalid joint kind or axis')
  assert(finite(lower) and finite(upper) and lower>=-180 and lower<=upper and upper<=180, 'invalid joint range')
  if kind=='Hinge' then assert(lower<=0 and upper>=0, 'hinge range must include zero') end
  assert(type(control)=='string' and #control>0 and #control<=128, 'control name must be 1–128 characters')
  assert(impulse==nil or (type(impulse)=='string' and #impulse>0 and #impulse<=128), 'invalid impulse name')
  assert(finite(frequency) and frequency>=0.01 and frequency<=100, 'invalid frequency')
  local mode=if kind=='Hinge' then 'scalar' else 'vector'
  assert(not controls[control] or controls[control]==mode,'control name cannot mix hinge and ball inputs: '..control)
  controls[control]=mode
  if impulse then
   assert(not impulses[impulse] or impulses[impulse]==mode,'impulse name cannot mix hinge and ball inputs: '..impulse)
   impulses[impulse]=mode
  end
  local jointConfig={name=ref.Name,control=control,impulse=impulse,frequency=frequency,lower=math.rad(lower),upper=math.rad(upper)}
  if kind=='Ball' then
   local swing=ref:GetAttribute('SwingDegrees')
   assert(finite(swing) and swing>=0 and swing<=180,'invalid ball swing')
   local v=axes[axis]; jointConfig.axis={v.X,v.Y,v.Z}; jointConfig.swing=math.rad(swing)
   table.insert(ballConfigs,jointConfig)
  else table.insert(hingeConfigs,jointConfig) end
  table.insert(bindings,{name=ref.Name,joint=ref.Value,axis=axes[axis],kind=kind})
 end
 assert(#bindings>0, 'actor has no configured joints')
 local behaviors,registry={},{}
 if #hingeConfigs>0 then
  table.insert(behaviors,{name='hinges',type='hinge',options={joints=hingeConfigs}}); registry.hinge=components.JointDrive.new
 end
 if #ballConfigs>0 then
  assert(components.BallDrive and type(components.BallDrive.new)=='function','ball drive component required')
  table.insert(behaviors,{name='balls',type='ball',options={joints=ballConfigs}}); registry.ball=components.BallDrive.new
 end
 local actor=components.Actor.new({behaviors=behaviors},registry)
 local ok,adapter=pcall(components.JointAdapter.new,bindings,{exclusive=true,baseMode=options.baseMode})
 if not ok then actor:destroy(); error(adapter) end
 local dead=false
 local api={}
 local function list(names)
  assert(not dead,'actor is destroyed')
  local result={}; for name in pairs(names) do table.insert(result,name) end; table.sort(result)
  return result
 end
 function api:listControls() return list(controls) end
 function api:listImpulses() return list(impulses) end
 function api:validateControl(name,value)
  assert(not dead,'actor is destroyed'); assert(controls[name],'unknown actor control: '..tostring(name))
  if controls[name]=='scalar' then assert(finite(value),'hinge control must be a finite number')
  else assert(type(value)=='table' and #value==3 and finite(value[1]) and finite(value[2]) and finite(value[3]),'ball control must be a finite three-number vector') end
 end
 function api:validateImpulse(name,value)
  assert(not dead,'actor is destroyed'); assert(impulses[name],'unknown actor impulse: '..tostring(name))
  if impulses[name]=='scalar' then assert(finite(value),'hinge impulse must be a finite scalar')
  else assert(type(value)=='table' and #value==3 and finite(value[1]) and finite(value[2]) and finite(value[3]),'ball impulse must be a finite three-number vector') end
 end
 function api:setControl(name,value)
  self:validateControl(name,value); actor:setControl(name,value)
 end
 function api:clearControl(name)
  assert(not dead,'actor is destroyed'); assert(controls[name],'unknown actor control: '..tostring(name)); actor:clearControl(name)
 end
 function api:impulse(name,value)
  self:validateImpulse(name,value); actor:impulse(name,value)
 end
 function api:step(dt)
  assert(not dead,'actor is destroyed')
  adapter:validate()
  local result=actor:step({},dt)
  local output={}
  for _,entry in ipairs(result) do for name,value in pairs(entry.value) do output[name]=value end end
  adapter:apply(output)
  return output
 end
 function api:destroy()
  if dead then return {} end
  dead=true
  local okAdapter,conflicts=pcall(adapter.destroy,adapter)
  local okActor,err=pcall(actor.destroy,actor)
  if not okAdapter then error(conflicts) end
  if not okActor then error(err) end
  return conflicts
 end
 return api
end
return ActorRig
