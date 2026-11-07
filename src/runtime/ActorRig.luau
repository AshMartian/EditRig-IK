--!strict
-- Experimental explicit-owner actor built from saved ObjectValue bindings.
local ActorRig={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function ActorRig.new(folder,components)
 assert(typeof(folder)=='Instance' and folder:IsA('Folder') and folder.Parent and folder.Parent:IsA('Model'),'actor definition must be a folder in a model')
 assert(folder:GetAttribute('EditRigIK_ActorSchemaVersion')==1, 'unsupported actor definition schema')
 assert(type(components)=='table' and components.Actor and components.JointDrive and components.JointAdapter,'runtime components required')
 local refs=folder:GetChildren()
 table.sort(refs,function(a,b) return a.Name<b.Name end)
 local jointConfigs,bindings,seen={}, {}, {}
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
  assert(kind=='Hinge' and axes[axis], 'only X/Y/Z hinge bindings are supported')
  assert(finite(lower) and finite(upper) and lower>=-180 and lower<=0 and upper>=0 and upper<=180, 'hinge range must include zero')
  assert(type(control)=='string' and #control>0 and #control<=128, 'control name must be 1–128 characters')
  assert(impulse==nil or (type(impulse)=='string' and #impulse>0 and #impulse<=128), 'invalid impulse name')
  assert(finite(frequency) and frequency>=0.01 and frequency<=100, 'invalid frequency')
  table.insert(jointConfigs,{name=ref.Name,control=control,impulse=impulse,frequency=frequency,lower=math.rad(lower),upper=math.rad(upper)})
  table.insert(bindings,{name=ref.Name,joint=ref.Value,axis=axes[axis]})
  controls[control]=true
  if impulse then impulses[impulse]=true end
 end
 assert(#bindings>0, 'actor has no configured joints')
 local actor=components.Actor.new({behaviors={{name='jointDrive',type='jointDrive',options={joints=jointConfigs}}}}, {jointDrive=components.JointDrive.new})
 local ok,adapter=pcall(components.JointAdapter.new,bindings,{exclusive=true})
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
 function api:setControl(name,value)
  assert(not dead,'actor is destroyed'); assert(controls[name],'unknown actor control: '..tostring(name))
  assert(finite(value),'joint control must be a finite number'); actor:setControl(name,value)
 end
 function api:clearControl(name)
  assert(not dead,'actor is destroyed'); assert(controls[name],'unknown actor control: '..tostring(name)); actor:clearControl(name)
 end
 function api:impulse(name,value)
  assert(not dead,'actor is destroyed'); assert(impulses[name],'unknown actor impulse: '..tostring(name))
  assert(finite(value),'joint impulse must be a finite scalar'); actor:impulse(name,value)
 end
 function api:step(dt)
  assert(not dead,'actor is destroyed')
  adapter:validate()
  local result=actor:step({},dt)
  adapter:apply(result[1].value)
  return result[1].value
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
