--!strict
-- Connect existing boolean InputActions to named actor controls and messages.
local InputBindings={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function nameValid(name) return type(name)=='string' and #name>0 and #name<=128 end
local function checkAction(action)
 assert(typeof(action)=='Instance' and action:IsA('InputAction') and action.Type==Enum.InputActionType.Bool,'expected a Bool InputAction')
end
function InputBindings.new(actor)
 assert(type(actor)=='table' and type(actor.setControl)=='function' and type(actor.impulse)=='function','actor control API required')
 local entries,controls={},{}
 local dead=false
 local api={}
 local function manage(connections,onClose)
  local closed=false
  local handle={}
  function handle:destroy()
   if closed then return end
   closed=true; entries[handle]=nil
   for _,connection in ipairs(connections) do connection:Disconnect() end
   onClose()
  end
  entries[handle]=true
  return handle
 end
 function api:bindHold(action,control,value)
  assert(not dead,'input bindings are destroyed'); checkAction(action)
  assert(nameValid(control) and finite(value) and value>=-1 and value<=1,'invalid control or hold value')
  assert(not controls[control],'control already has a hold binding')
  local state=action:GetState(); assert(type(state)=='boolean','Bool action state unavailable')
  actor:setControl(control,if state then value else 0)
  local active=state
  local handle
  local connections={}
  connections[1]=action.StateChanged:Connect(function(nextState)
   local pressed=nextState==true
   actor:setControl(control,if pressed then value else 0)
   active=pressed
  end)
  connections[2]=action.Destroying:Connect(function() if handle then handle:destroy() end end)
  connections[3]=action:GetPropertyChangedSignal('Type'):Connect(function()
   if handle and action.Type~=Enum.InputActionType.Bool then handle:destroy() end
  end)
  handle=manage(connections,function()
   controls[control]=nil
   if active then actor:setControl(control,0) end
  end)
  controls[control]=handle
  return handle
 end
 function api:bindImpulse(action,impulse,value)
  assert(not dead,'input bindings are destroyed'); checkAction(action)
  assert(nameValid(impulse),'invalid impulse name')
  local payload
  if finite(value) then payload=value else
   assert(type(value)=='table' and #value==3 and finite(value[1]) and finite(value[2]) and finite(value[3]),'impulse must be a finite number or three-number vector')
   payload={value[1],value[2],value[3]}
  end
  local handle
  local connections={}
  connections[1]=action.Pressed:Connect(function() actor:impulse(impulse,payload) end)
  connections[2]=action.Destroying:Connect(function() if handle then handle:destroy() end end)
  connections[3]=action:GetPropertyChangedSignal('Type'):Connect(function()
   if handle and action.Type~=Enum.InputActionType.Bool then handle:destroy() end
  end)
  handle=manage(connections,function() end)
  return handle
 end
 function api:bindProfile(context)
  assert(not dead,'input bindings are destroyed')
  assert(typeof(context)=='Instance' and context:IsA('InputContext') and not context.Enabled,'expected a disabled InputContext')
  local planned,seen={},{}
  for _,action in ipairs(context:GetChildren()) do
   if action:IsA('InputAction') then
    checkAction(action)
    local route,control,value=action:GetAttribute('Route'),action:GetAttribute('Control'),action:GetAttribute('Value')
    assert((route=='Hold' or route=='Impulse') and nameValid(control) and finite(value),'invalid input profile action')
    if route=='Hold' then
     assert(value>=-1 and value<=1 and not controls[control] and not seen[control],'invalid or duplicate hold control')
     seen[control]=true
    end
    table.insert(planned,{action=action,route=route,control=control,value=value})
   end
  end
  assert(#planned>0,'input profile contains no actions')
  local handles={}
  local ok,err=pcall(function()
   for _,entry in ipairs(planned) do
    local handle=if entry.route=='Hold' then api:bindHold(entry.action,entry.control,entry.value) else api:bindImpulse(entry.action,entry.control,entry.value)
    table.insert(handles,handle)
   end
  end)
  if not ok then for _,handle in ipairs(handles) do pcall(function() handle:destroy() end) end; error(err) end
  local closed=false
  return {destroy=function()
   if closed then return end
   closed=true
   local errors={}
   for _,handle in ipairs(handles) do local success,message=pcall(function() handle:destroy() end); if not success then table.insert(errors,tostring(message)) end end
   if #errors>0 then error(table.concat(errors,'; ')) end
  end}
 end
 function api:destroy()
  if dead then return end
  dead=true
  local errors={}
  for handle in pairs(entries) do
   local ok,err=pcall(function() handle:destroy() end)
   if not ok then table.insert(errors,tostring(err)) end
  end
  if #errors>0 then error(table.concat(errors,'; ')) end
 end
 return api
end
return InputBindings
