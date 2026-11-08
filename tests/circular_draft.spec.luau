local Draft=require('../src/plugin/CircularDraft')
local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b)) end
local wrapped={start=150,width=60}
near(Draft.endpoint(wrapped),-150)
local moved=Draft.setBound(wrapped,'upper',-140)
near(moved.start,150); near(moved.width,70)
moved=Draft.setBound(wrapped,'lower',160)
near(moved.start,160); near(moved.width,50)
moved=Draft.shift(wrapped,40)
near(moved.start,-170); near(moved.width,60)
local full={start=-180,width=360}
near(Draft.setBound(full,'upper',180).width,360)
near(Draft.setBound(full,'lower',180).width,360)
local locked={start=30,width=0}
near(Draft.setBound(locked,'upper',30).width,0)
near(Draft.setBound(locked,'lower',30).width,0)
assert(not pcall(Draft.setBound,wrapped,'upper',181),'invalid displayed angles must fail')
assert(not pcall(Draft.setBound,wrapped,'other',1),'unknown bound must fail')
assert(not pcall(Draft.shift,{start=0,width=361},5),'invalid interval must fail')
print('circular draft editing passed')
