--!strict
-- Output joint-local angles for named controls and damped angular impulses.
-- No instances are modified by this behavior.
local JointDrive = {}
local function finite(n)
 return type(n)=='number' and n==n and math.abs(n)<math.huge
end
function JointDrive.new(options)
 assert(type(options)=='table' and type(options.joints)=='table' and #options.joints>0,'joint bindings required')
 local states,seen={},{}
 for _,binding in ipairs(options.joints) do
  assert(type(binding.name)=='string' and binding.name~='' and not seen[binding.name], 'duplicate or invalid joint name')
  assert(type(binding.control)=='string' and binding.control~='', 'control name required')
  assert(binding.impulse==nil or (type(binding.impulse)=='string' and binding.impulse~=''), 'invalid impulse name')
  assert(finite(binding.lower) and finite(binding.upper) and binding.lower>=-math.pi and binding.lower<=0 and binding.upper>=0 and binding.upper<=math.pi, 'invalid joint range')
  assert(finite(binding.frequency) and binding.frequency>=0.01 and binding.frequency<=100, 'invalid damping frequency')
  seen[binding.name]=true
  table.insert(states,{binding=binding,offset=0,velocity=0})
 end
 local behavior={}
 function behavior.step(_,dt,signals)
  assert(finite(dt) and dt>=0, 'invalid delta time')
  local output={}
  for _,state in ipairs(states) do
   local b=state.binding
   local value=signals.values[b.control]
   if value==nil then value=0 end
   assert(finite(value),'joint control must be a finite number')
   value=math.clamp(value,-1,1)
   for _,imp in ipairs(signals.impulses) do
    if b.impulse and imp.name==b.impulse then
     assert(finite(imp.value),'joint impulse must be a finite scalar')
     state.velocity=math.clamp(state.velocity+math.clamp(imp.value,-100,100),-100,100)
    end
   end
   -- Analytic critically damped response; frequency is angular frequency in 1/s.
   local w=b.frequency
   local decay=if w*dt>700 then 0 else math.exp(-w*dt)
   if decay==0 then state.offset=0; state.velocity=0 else
    local temp=state.velocity+w*state.offset
    state.offset=(state.offset+temp*dt)*decay
    state.velocity=(state.velocity-w*temp*dt)*decay
   end
   local target=if value>=0 then value*b.upper else -value*b.lower
   output[b.name]=math.clamp(target+state.offset,b.lower,b.upper)
  end
  return output
 end
 return behavior
end
return JointDrive
