local Limits = require('../src/shared/Limits')

local function near(a, b, epsilon)
    assert(math.abs(a - b) < (epsilon or 1e-6), tostring(a) .. ' ~= ' .. tostring(b))
end

-- Quaternion order is x, y, z, w. Hinge angles are signed, radians.
local function aroundY(angle)
    return {0, math.sin(angle / 2), 0, math.cos(angle / 2)}
end
local axis = {0, 1, 0}
local clamped = Limits.hinge(aroundY(math.rad(90)), axis, math.rad(-20), math.rad(45))
near(clamped[2], math.sin(math.rad(45) / 2))
near(clamped[4], math.cos(math.rad(45) / 2))
local inside = Limits.hinge(aroundY(math.rad(-10)), axis, math.rad(-20), math.rad(45))
near(inside[2], math.sin(math.rad(-10) / 2))
local flipped = Limits.hinge({0, -math.sin(math.rad(90)/2), 0, -math.cos(math.rad(90)/2)}, axis, math.rad(-20), math.rad(45))
near(flipped[2], clamped[2]); near(flipped[4], clamped[4])
local ok = pcall(function() Limits.hinge(aroundY(0), {0,0,0}, -1, 1) end)
assert(not ok, 'zero axis must be rejected')

local swing = {math.sin(math.rad(80)/2), 0, 0, math.cos(math.rad(80)/2)}
local limited = Limits.ball(swing, axis, math.rad(30), math.rad(-20), math.rad(20))
near(limited[1], math.sin(math.rad(30)/2)); near(limited[4], math.cos(math.rad(30)/2))
local twistLimited = Limits.ball(aroundY(math.rad(-70)), axis, math.rad(30), math.rad(-20), math.rad(20))
near(twistLimited[2], math.sin(math.rad(-20)/2))
local minusSwing = Limits.ball({-swing[1], 0, 0, -swing[4]}, axis, math.rad(30), -1, 1)
near(minusSwing[1], limited[1]); near(minusSwing[4], limited[4])
assert(not pcall(function() Limits.ball(swing, axis, -1, -1, 1) end))
-- At exactly 180 degrees, q and -q represent the same pose and must
-- resolve consistently even when the permitted interval is positive.
local halfTurn = Limits.hinge({0, 1, 0, 0}, axis, 0, math.pi)
local negativeHalfTurn = Limits.hinge({0, -1, 0, 0}, axis, 0, math.pi)
near(halfTurn[2], 1); near(negativeHalfTurn[2], 1)

print('joint limit tests passed')
