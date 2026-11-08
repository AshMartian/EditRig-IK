--!strict
local Config = {}
local function finite(value: any): boolean
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end
function Config.validate(input: any): any
    assert(type(input) == 'table', 'configuration must be a table')
    assert(input.kind == 'Hinge' or input.kind == 'Ball', 'kind must be Hinge or Ball')
    assert(input.axis == 'X' or input.axis == 'Y' or input.axis == 'Z', 'axis must be X, Y or Z')
    assert(finite(input.lower) and finite(input.upper) and input.lower >= -180 and input.lower <= 180 and input.upper >= -180 and input.upper <= 180, 'invalid twist/hinge range')
    local circular = nil
    if input.circular ~= nil then
        local c = input.circular
        assert(input.kind == 'Hinge' and type(c) == 'table' and finite(c.start) and finite(c.width) and c.width >= 0 and c.width <= 360, 'invalid circular hinge interval')
        local function canonical(angle) return (angle + 180) % 360 - 180 end
        local start = canonical(c.start)
        local function equivalent(a, b) return math.abs(canonical(a - b)) < 1e-7 end
        assert(equivalent(input.lower, start) and equivalent(input.upper, start + c.width), 'circular endpoints disagree with interval')
        circular = {start=start, width=c.width}
    else
        assert(input.lower <= input.upper, 'invalid twist/hinge range')
    end
    assert(finite(input.swing) and input.swing >= 0 and input.swing <= 180, 'invalid swing angle')
    local weight = if input.weight == nil then 1 else input.weight
    assert(finite(weight) and weight >= 0 and weight <= 1, 'joint influence must be between 0 and 1')
    return {kind=input.kind, axis=input.axis, lower=input.lower, upper=input.upper, swing=input.swing, weight=weight, circular=circular}
end
function Config.validateDrive(input: any, jointName: string): any
    assert(type(input)=='table' and type(jointName)=='string' and jointName~='', 'joint name required')
    local control=if input.control==nil or input.control=='' then jointName else input.control
    local impulse=if input.impulse==nil or input.impulse=='' then jointName..'Impulse' else input.impulse
    local frequency=if input.frequency==nil then 4 else input.frequency
    assert(type(control)=='string' and #control>0 and #control<=128, 'control name must be 1–128 characters')
    assert(type(impulse)=='string' and #impulse>0 and #impulse<=128, 'impulse name must be 1–128 characters')
    assert(finite(frequency) and frequency>=0.01 and frequency<=100, 'damping frequency must be between 0.01 and 100')
    return {control=control,impulse=impulse,frequency=frequency}
end
return Config
