--!strict
-- Quaternion layout: {x, y, z, w}; vectors: {x, y, z}; angles: radians.
-- Inputs and outputs are joint-local rotations relative to the saved rest frame.
local Limits = {}

local function normalize(q: {number}): {number}
    local m = math.sqrt(q[1]^2 + q[2]^2 + q[3]^2 + q[4]^2)
    assert(m > 1e-12 and m < math.huge, 'invalid quaternion')
    return {q[1]/m, q[2]/m, q[3]/m, q[4]/m}
end

local function unit(v: {number}): {number}
    local m = math.sqrt(v[1]^2 + v[2]^2 + v[3]^2)
    assert(m > 1e-12 and m < math.huge, 'invalid axis')
    return {v[1]/m, v[2]/m, v[3]/m}
end

local function multiply(a: {number}, b: {number}): {number}
    local x,y,z,w = a[1],a[2],a[3],a[4]
    local X,Y,Z,W = b[1],b[2],b[3],b[4]
    return {w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X, w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z}
end

local function twist(q: {number}, a: {number}): ({number}, number)
    local dot = q[1]*a[1] + q[2]*a[2] + q[3]*a[3]
    local m = math.sqrt(dot*dot + q[4]*q[4])
    -- At an exact 180-degree swing the twist is undefined; choose zero twist.
    if m < 1e-12 then return {0,0,0,1}, 0 end
    local angle = 2*math.atan2(dot/m, q[4]/m)
    angle = (angle + math.pi) % (2*math.pi) - math.pi
    -- Both quaternion signs at the half-turn map to the same positive angle.
    if math.abs(angle + math.pi) < 1e-12 then angle = math.pi end
    return {a[1]*math.sin(angle/2), a[2]*math.sin(angle/2), a[3]*math.sin(angle/2), math.cos(angle/2)}, angle
end

local function range(lower: number, upper: number)
    assert(lower == lower and upper == upper and lower >= -math.pi and upper <= math.pi and lower <= upper, 'invalid angular range')
end

local function chooseHalfTurn(angle: number, lower: number, upper: number): number
    if math.abs(angle - math.pi) < 1e-12 and lower + math.pi < math.pi - upper then
        return -math.pi
    end
    return angle
end

function Limits.hinge(rotation: {number}, axis: {number}, lower: number, upper: number): {number}
    range(lower, upper)
    local a = unit(axis)
    local _, angle = twist(normalize(rotation), a)
    local half = math.clamp(chooseHalfTurn(angle, lower, upper), lower, upper)/2
    return {a[1]*math.sin(half), a[2]*math.sin(half), a[3]*math.sin(half), math.cos(half)}
end

function Limits.ball(rotation: {number}, axis: {number}, maxSwing: number, lowerTwist: number, upperTwist: number): {number}
    range(lowerTwist, upperTwist)
    assert(maxSwing == maxSwing and maxSwing >= 0 and maxSwing <= math.pi, 'invalid swing angle')
    local a = unit(axis)
    local q = normalize(rotation)
    local t, angle = twist(q, a)
    local swing = normalize(multiply(q, {-t[1],-t[2],-t[3],t[4]}))
    if swing[4] < 0 then swing = {-swing[1],-swing[2],-swing[3],-swing[4]} end
    local vectorLength = math.sqrt(swing[1]^2+swing[2]^2+swing[3]^2)
    local swingAngle = 2*math.atan2(vectorLength, swing[4])
    if swingAngle > maxSwing and vectorLength > 1e-12 then
        local s = math.sin(maxSwing/2)/vectorLength
        swing = {swing[1]*s, swing[2]*s, swing[3]*s, math.cos(maxSwing/2)}
    end
    local half = math.clamp(chooseHalfTurn(angle, lowerTwist, upperTwist), lowerTwist, upperTwist)/2
    local limitedTwist = {a[1]*math.sin(half),a[2]*math.sin(half),a[3]*math.sin(half),math.cos(half)}
    return normalize(multiply(swing, limitedTwist))
end

return Limits
