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

print('actor framework tests passed')
