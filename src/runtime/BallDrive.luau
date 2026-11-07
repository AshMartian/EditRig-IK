--!strict
-- Pure ball-joint behavior: local rotation vectors and damped angular impulses.
local BallDrive={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function vector(v,label)
 assert(type(v)=='table' and #v==3 and finite(v[1]) and finite(v[2]) and finite(v[3]),label..' must be a finite three-number vector')
 return {v[1],v[2],v[3]}
end
function BallDrive.new(options,limits)
 assert(type(options)=='table' and type(options.joints)=='table' and #options.joints>0,'joint bindings required')
 assert(type(limits)=='table' and type(limits.ball)=='function','ball limit function required')
 local states,seen={},{}
 for _,b in ipairs(options.joints) do
  assert(type(b.name)=='string' and #b.name>0 and #b.name<=128 and not seen[b.name],'invalid or duplicate joint name')
  assert(type(b.control)=='string' and #b.control>0 and #b.control<=128,'invalid control name')
  assert(b.impulse==nil or (type(b.impulse)=='string' and #b.impulse>0 and #b.impulse<=128),'invalid impulse name')
  local axis=vector(b.axis,'axis')
  local magnitude=math.sqrt(axis[1]^2+axis[2]^2+axis[3]^2)
  assert(magnitude>1e-12 and magnitude<math.huge,'invalid axis')
  assert(finite(b.lower) and finite(b.upper) and b.lower>=-math.pi and b.upper<=math.pi and b.lower<=b.upper,'invalid twist range')
  assert(finite(b.swing) and b.swing>=0 and b.swing<=math.pi,'invalid swing angle')
  assert(finite(b.frequency) and b.frequency>=.01 and b.frequency<=100,'invalid damping frequency')
  seen[b.name]=true
  table.insert(states,{name=b.name,control=b.control,impulse=b.impulse,axis=axis,lower=b.lower,upper=b.upper,swing=b.swing,frequency=b.frequency,offset={0,0,0},velocity={0,0,0}})
 end
 local behavior={}
 function behavior.step(_,dt,signals)
  assert(finite(dt) and dt>=0,'invalid delta time')
  local outputs,nextStates={},{}
  for index,state in ipairs(states) do
   local control=if signals.values[state.control]==nil then {0,0,0} else vector(signals.values[state.control],'ball control')
   local velocity={state.velocity[1],state.velocity[2],state.velocity[3]}
   for _,message in ipairs(signals.impulses) do
    if state.impulse and message.name==state.impulse then
     local delta=vector(message.value,'ball impulse')
     for i=1,3 do velocity[i]=math.clamp(velocity[i]+math.clamp(delta[i],-100,100),-100,100) end
    end
   end
   local offset,nextVelocity={},{}
   local w=state.frequency; local decay=if w*dt>700 then 0 else math.exp(-w*dt)
   for i=1,3 do
    if decay==0 then offset[i]=0; nextVelocity[i]=0 else
     local temp=velocity[i]+w*state.offset[i]
     offset[i]=(state.offset[i]+temp*dt)*decay
     nextVelocity[i]=(velocity[i]-w*temp*dt)*decay
    end
   end
   local v={}
   for i=1,3 do v[i]=math.clamp(control[i],-100,100)+offset[i] end
   local magnitude=math.sqrt(v[1]^2+v[2]^2+v[3]^2)
   local q
   if magnitude<1e-12 then q={0,0,0,1} else
    local angle=math.min(magnitude,math.pi); local factor=math.sin(angle/2)/magnitude
    q={v[1]*factor,v[2]*factor,v[3]*factor,math.cos(angle/2)}
   end
   outputs[state.name]=limits.ball(q,state.axis,state.swing,state.lower,state.upper)
   nextStates[index]={offset=offset,velocity=nextVelocity}
  end
  for index,state in ipairs(states) do state.offset=nextStates[index].offset; state.velocity=nextStates[index].velocity end
  return outputs
 end
 return behavior
end
return BallDrive
