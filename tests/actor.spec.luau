local Actor = require('../src/runtime/Actor')
local closed = 0
local registry = {count = function(config)
    local count = 0
    return {step=function(input,dt) count+=1; return {value=count, speed=input.speed, dt=dt, gain=config.gain} end,
        destroy=function() closed+=1 end}
end}
local spec = {behaviors={{name='late',type='count',priority=2,options={gain=2}}, {name='early',type='count',priority=1,options={gain=3}}}}
local a=Actor.new(spec,registry)
local b=Actor.new(spec,registry)
local out=a:step({speed=4},.1)
assert(out[1].name=='early' and out[2].name=='late' and out[1].value.value==1)
assert(a:step({speed=5},.2)[1].value.value==2)
assert(b:step({speed=5},.2)[1].value.value==1, 'actor state must be independent')
a:setEnabled('early',false)
assert(#a:step({speed=2},.1)==1)
assert(not pcall(function() a:setEnabled('missing',true) end))
a:destroy(); a:destroy()
assert(closed==2, 'each behavior must be destroyed exactly once')
assert(not pcall(function() a:step({},.1) end))
b:destroy()
assert(not pcall(function() Actor.new({behaviors={{name='a',type='missing'}}},registry) end))
local cleaned = 0
local factories = {
 good=function() return {step=function() end,destroy=function() cleaned+=1 end} end,
 bad=function() return {destroy=function() cleaned+=1 end} end,
}
assert(not pcall(function() Actor.new({behaviors={{name='good',type='good'}, {name='bad',type='bad'}}},factories) end))
assert(cleaned==2, 'partially constructed behaviors must be cleaned up')

local observed = {}
local inputRegistry = {listen=function() return {step=function(_,_,controls)
    table.insert(observed, controls)
    return controls
end} end}
local controller = Actor.new({behaviors={{name='listener',type='listen'}}}, inputRegistry)
controller:setControl('JawOpen', 0.75)
controller:impulse('Tail', {1,2,3})
controller:step({},0.1)
assert(observed[1].values.JawOpen==0.75)
assert(#observed[1].impulses==1 and observed[1].impulses[1].name=='Tail' and observed[1].impulses[1].value[2]==2)
controller:step({},0.1)
assert(observed[2].values.JawOpen==0.75 and #observed[2].impulses==0)
assert(not pcall(function() controller:setControl('', 1) end))
assert(not pcall(function() controller:impulse('Tail', 0/0) end))
controller:destroy()
assert(not pcall(function() controller:setControl('x',1) end))

local snapshots={}
local reg={capture=function() return {step=function(_,_,controls) table.insert(snapshots,controls.values) end} end}
local c=Actor.new({behaviors={{name='capture',type='capture'}}},reg)
c:setControl('JawOpen',1); c:clearControl('JawOpen'); c:step({},.1)
assert(snapshots[1].JawOpen==nil, 'cleared control should not remain active')

print('actor framework tests passed')
