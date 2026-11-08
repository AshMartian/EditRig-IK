local LimitFrame = require('../src/shared/LimitFrame')
local Limits = require('../src/shared/Limits')
local function near(a,b) assert(math.abs(a-b)<1e-9,tostring(a)..' ~= '..tostring(b)) end
local function vector(actual,expected) for i=1,3 do near(actual[i],expected[i]) end end
for _,case in ipairs({
 {'X',{1,0,0},{0,1,0},{0,0,1}},
 {'Y',{0,1,0},{0,0,1},{1,0,0}},
 {'Z',{0,0,1},{1,0,0},{0,1,0}},
}) do
 local basis=LimitFrame.basis(case[1],nil)
 vector(basis.axis,case[2]); vector(basis.reference,case[3]); vector(basis.tangent,case[4])
end
local half=math.pi/8
local q={0,0,math.sin(half),math.cos(half)}
local basis=LimitFrame.basis('X',q)
local c=math.sqrt(.5)
vector(basis.axis,{c,c,0}); vector(basis.reference,{-c,c,0}); vector(basis.tangent,{0,0,1})
local inverseSign=LimitFrame.basis('X',{0,0,-q[3],-q[4]})
vector(inverseSign.axis,basis.axis); vector(inverseSign.reference,basis.reference)
local normalized=LimitFrame.normalize({0,0,-2*q[3],-2*q[4]})
for i=1,4 do near(normalized[i],q[i]) end
local a=LimitFrame.normalize({0,-1,0,0}); local b=LimitFrame.normalize({0,1,0,0})
for i=1,4 do near(a[i],b[i]) end
local angle=math.rad(70); local clamped=Limits.hinge({basis.axis[1]*math.sin(angle/2),basis.axis[2]*math.sin(angle/2),0,math.cos(angle/2)},basis.axis,math.rad(-20),math.rad(30))
near(clamped[1],c*math.sin(math.rad(15))); near(clamped[2],c*math.sin(math.rad(15))); near(clamped[4],math.cos(math.rad(15)))
for _,invalid in ipairs({{0,0,0,0},{0/0,0,0,1},{math.huge,0,0,1},{1,0,0},{'x',0,0,1}}) do
 assert(not pcall(LimitFrame.normalize,invalid),'invalid quaternion must be rejected')
end
assert(not pcall(LimitFrame.basis,'Q',nil),'invalid axis must be rejected')
local shifted=LimitFrame.shiftInterval(math.rad(-30),math.rad(20),math.rad(45))
near(shifted.lower,math.rad(15)); near(shifted.upper,math.rad(65))
assert(not shifted.wraps and not shifted.full,'ordinary offset remains one interval')
local roll=LimitFrame.basis('X',{math.sin(math.pi/4),0,0,math.cos(math.pi/4)})
vector(roll.axis,{1,0,0}); vector(roll.reference,{0,0,1})
local rollDoesNotShift=LimitFrame.shiftInterval(math.rad(-30),math.rad(20),0)
near(rollDoesNotShift.lower,math.rad(-30)); near(rollDoesNotShift.upper,math.rad(20))
local wrapped=LimitFrame.shiftInterval(math.rad(-20),math.rad(40),math.rad(170))
near(wrapped.lower,math.rad(150)); near(wrapped.upper,math.rad(-150))
assert(wrapped.wraps and not wrapped.full,'an interval crossing 180 degrees must be explicit')
local full=LimitFrame.shiftInterval(-math.pi,math.pi,math.rad(50))
assert(full.full and not full.wraps,'a full revolution remains unrestricted')
local unchanged=LimitFrame.shiftInterval(0,math.pi,0)
near(unchanged.lower,0); near(unchanged.upper,math.pi); assert(not unchanged.wraps,'touching the boundary is not a crossing')
assert(not pcall(LimitFrame.shiftInterval,0,1,math.huge),'nonfinite offsets are rejected')
assert(not pcall(LimitFrame.shiftInterval,1,-1,0),'invalid base ranges are rejected')
print('limit frame tests passed')
