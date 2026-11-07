local Drive=require('../src/runtime/JointDrive')
local Actor=require('../src/runtime/Actor')
local spec={behaviors={{name='joints',type='joint',options={joints={{name='Jaw',control='jaw',impulse='tap',lower=-0.5,upper=1,frequency=4}}}}}}
local actor=Actor.new(spec,{joint=Drive.new})
actor:setControl('jaw',1)
local out=actor:step({},0.1)[1].value
assert(out.Jaw==1,'control should map to upper limit')
actor:setControl('jaw',-1)
out=actor:step({},0.1)[1].value
assert(out.Jaw==-0.5,'negative control should map to lower limit')
actor:setControl('jaw',0)
actor:impulse('tap',1)
local initial=actor:step({},0.1)[1].value.Jaw
assert(initial>0 and initial<1,'impulse should move joint within limits')
local later=initial
for _=1,100 do later=actor:step({},0.1)[1].value.Jaw end
assert(math.abs(later)<0.001,'impulse should decay back to neutral')
assert(not pcall(function() Drive.new({joints={{name='x',control='x',lower=2,upper=1,frequency=1}}}) end))
-- A rejected input on a later joint must not advance earlier impulse state.
local two={behaviors={{name='joints',type='joint',options={joints={
 {name='Jaw',control='jaw',impulse='tap',lower=-1,upper=1,frequency=4},
 {name='Tail',control='tail',lower=-1,upper=1,frequency=4},
}}}}}
local retry=Actor.new(two,{joint=Drive.new})
local fresh=Actor.new(two,{joint=Drive.new})
retry:setControl('tail',true)
retry:impulse('tap',1)
assert(not pcall(function() retry:step({},0.1) end), 'non-scalar joint control must be rejected')
retry:setControl('tail',0)
fresh:setControl('tail',0)
fresh:impulse('tap',1)
local retried=retry:step({},0.1)[1].value.Jaw
local expected=fresh:step({},0.1)[1].value.Jaw
assert(math.abs(retried-expected)<1e-12, 'failed step must not advance joint drive state')
print('joint drive tests passed')
