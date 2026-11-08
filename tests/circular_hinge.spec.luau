local Circular=require('../src/shared/CircularHinge').v1
local rad=math.rad
local function near(a,b,epsilon) assert(math.abs(a-b)<(epsilon or 1e-8),tostring(a)..' ~= '..tostring(b)) end
local function q(angle) return {0,math.sin(angle/2),0,math.cos(angle/2)} end
local wrapped=Circular.new(rad(150),rad(60))
near(Circular.clamp(wrapped,rad(170)),rad(170))
near(Circular.clamp(wrapped,rad(-170)),rad(-170))
near(Circular.clamp(wrapped,rad(140)),rad(150))
near(Circular.clamp(wrapped,rad(-140)),rad(-150))
near(Circular.clamp(wrapped,0),rad(150)) -- equal circular distance chooses start
near(Circular.clamp(wrapped,math.pi),-math.pi) -- canonical seam
near(Circular.clamp(wrapped,-math.pi),-math.pi)
local zero=Circular.new(rad(35),0)
near(Circular.clamp(zero,rad(-100)),rad(35))
local full=Circular.new(rad(35),2*math.pi)
near(Circular.clamp(full,rad(-100)),rad(-100))
for _,angle in ipairs({0,rad(140),rad(170),math.pi,rad(-170),rad(-140)}) do
 local original=q(angle)
 local negated={-original[1],-original[2],-original[3],-original[4]}
 local a=Circular.hinge(original,{0,1,0},wrapped)
 local b=Circular.hinge(negated,{0,1,0},wrapped)
 for i=1,4 do near(a[i],b[i]) end
 local expected=q(Circular.clamp(wrapped,angle))
 for i=1,4 do near(a[i],expected[i]) end
end
for degree=-180,180 do
 local result=Circular.clamp(wrapped,rad(degree))
 local distance=(result-wrapped.start)%(2*math.pi)
 assert(distance<=wrapped.width+1e-10 or math.abs(distance-2*math.pi)<1e-10,'clamped angle must lie on the allowed arc')
 local input=q(rad(degree)); local inverse={-input[1],-input[2],-input[3],-input[4]}
 local a=Circular.hinge(input,{0,4,0},wrapped); local b=Circular.hinge(inverse,{0,4,0},wrapped)
 for i=1,4 do near(a[i],b[i]) end
end
local singular=Circular.hinge({1,0,0,0},{0,1,0},wrapped)
local zeroClamped=q(rad(150)); for i=1,4 do near(singular[i],zeroClamped[i]) end
assert(not pcall(Circular.new,0,-1),'negative width is invalid')
assert(not pcall(Circular.new,0,2*math.pi+1e-6),'width greater than one revolution is invalid')
assert(not pcall(Circular.new,math.huge,1),'nonfinite start is invalid')
assert(not pcall(Circular.clamp,{start=0,width=0/0},0),'invalid interval is rejected')
assert(not pcall(Circular.hinge,{0,0,0,0},{0,1,0},wrapped),'zero quaternion is invalid')
assert(not pcall(Circular.hinge,{0,0,0,1},{0,0,0},wrapped),'zero axis is invalid')
assert(not pcall(Circular.hinge,{0,0,0,math.huge},{0,1,0},wrapped),'nonfinite quaternion is invalid')
assert(not pcall(Circular.hinge,{0,0,0,1},{0,math.huge,0},wrapped),'nonfinite axis is invalid')
print('explicit circular hinge v1 tests passed')
