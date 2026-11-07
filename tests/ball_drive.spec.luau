local Actor=require('../src/runtime/Actor')
local BallDrive=require('../src/runtime/BallDrive')
local Limits=require('../src/shared/Limits')
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
local binding={name='Shoulder',control='Aim',impulse='Push',axis={0,1,0},lower=-math.pi/4,upper=math.pi/4,swing=math.pi/6,frequency=4}
local function actor() return Actor.new({behaviors={{name='ball',type='ball',options={joints={binding}}}}},{ball=function(opts) return BallDrive.new(opts,Limits) end}) end
local a=actor(); a:setControl('Aim',{math.pi/2,0,0})
local q=a:step({},0)[1].value.Shoulder
near(q[1],math.sin(math.pi/12)); near(q[4],math.cos(math.pi/12))
a:setControl('Aim',{0,math.pi/2,0}); q=a:step({},0)[1].value.Shoulder
near(q[2],math.sin(math.pi/8)); near(q[4],math.cos(math.pi/8))
a:clearControl('Aim'); a:impulse('Push',{1,0,0}); q=a:step({},.1)[1].value.Shoulder
assert(q[1]>0,'angular impulse should move joint')
for _=1,100 do q=a:step({},.1)[1].value.Shoulder end
assert(math.abs(q[1])<.001,'damped impulse should settle')
local retry=actor(); local fresh=actor(); retry:impulse('Push',{1,0,0}); fresh:impulse('Push',{1,0,0})
retry:setControl('Aim',true)
assert(not pcall(function() retry:step({},.1) end),'invalid control must be rejected')
retry:clearControl('Aim')
local r=retry:step({},.1)[1].value.Shoulder; local f=fresh:step({},.1)[1].value.Shoulder
near(r[1],f[1]); near(r[4],f[4])
assert(not pcall(function() BallDrive.new({joints={{name='x',control='c',axis={0,0,0},lower=-1,upper=1,swing=1,frequency=4}}},Limits) end),'zero axis must be rejected')
a:destroy(); retry:destroy(); fresh:destroy()
-- A failure on a later joint must not partially advance an earlier joint.
local second={name='Tail',control='TailControl',axis={0,1,0},lower=-1,upper=1,swing=1,frequency=4}
local function twoJoints()
 return Actor.new({behaviors={{name='ball',type='ball',options={joints={binding,second}}}}},{ball=function(opts) return BallDrive.new(opts,Limits) end})
end
local failed=twoJoints(); local baseline=twoJoints()
failed:impulse('Push',{1,0,0}); baseline:impulse('Push',{1,0,0}); failed:setControl('TailControl',true)
assert(not pcall(function() failed:step({},.1) end),'invalid later control must reject the whole update')
failed:clearControl('TailControl')
local after=failed:step({},.1)[1].value.Shoulder; local expected=baseline:step({},.1)[1].value.Shoulder
near(after[1],expected[1]); near(after[4],expected[4]); failed:destroy(); baseline:destroy()

print('ball drive tests passed')
