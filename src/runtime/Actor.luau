--!strict
-- Registry-backed behavior coordinator. It does not yet control rig instances.
local Actor = {}
local function copy(value, seen)
 if type(value)~='table' then return value end
 assert(not seen[value], 'cyclic behavior options are not supported')
 seen[value]=true
 local result={}
 for k,v in pairs(value) do result[copy(k,seen)]=copy(v,seen) end
 seen[value]=nil
 return result
end
function Actor.new(definition, registry)
 assert(type(definition)=='table' and type(definition.behaviors)=='table' and type(registry)=='table', 'invalid actor definition')
 local entries,byName={},{}
 local destroyed=false
 local ok,err=pcall(function()
  for index, spec in ipairs(definition.behaviors) do
   assert(type(spec.name)=='string' and spec.name~='' and not byName[spec.name], 'invalid or duplicate behavior name')
   assert(type(spec.type)=='string' and type(registry[spec.type])=='function', 'unknown behavior type')
   local priority=spec.priority or 0
   assert(type(priority)=='number' and priority==priority and math.abs(priority)<math.huge, 'invalid behavior priority')
   local behavior=registry[spec.type](copy(spec.options or {},{}))
   if type(behavior)~='table' or type(behavior.step)~='function' then
    if type(behavior)=='table' and type(behavior.destroy)=='function' then pcall(behavior.destroy,behavior) end
    error('behavior must have a step function')
   end
   local entry={name=spec.name,priority=priority,index=index,enabled=spec.enabled~=false,behavior=behavior}
   table.insert(entries,entry); byName[spec.name]=entry
  end
 end)
 if not ok then
  for _,entry in ipairs(entries) do if type(entry.behavior.destroy)=='function' then pcall(entry.behavior.destroy,entry.behavior) end end
  error(err)
 end
 table.sort(entries,function(a,b) if a.priority==b.priority then return a.index<b.index end return a.priority<b.priority end)
 local api={}
 function api:step(input,dt)
  assert(not destroyed,'actor is destroyed')
  assert(type(dt)=='number' and dt==dt and dt>=0 and dt<math.huge,'invalid delta time')
  local outputs={}
  for _,entry in ipairs(entries) do
   if entry.enabled then table.insert(outputs,{name=entry.name,value=entry.behavior.step(input,dt)}) end
  end
  return outputs
 end
 function api:setEnabled(name,enabled)
  assert(not destroyed,'actor is destroyed')
  assert(byName[name] and type(enabled)=='boolean','invalid behavior or enabled flag')
  byName[name].enabled=enabled
 end
 function api:destroy()
  if destroyed then return end
  destroyed=true
  local errors={}
  for _,entry in ipairs(entries) do
   if type(entry.behavior.destroy)=='function' then
    local success,message=pcall(entry.behavior.destroy,entry.behavior)
    if not success then table.insert(errors,tostring(message)) end
   end
  end
  if #errors>0 then error(table.concat(errors,'; ')) end
 end
 return api
end
return Actor
