--!strict
local Config = {}
local function finite(value: any): boolean
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end
function Config.validate(input: any): any
    assert(type(input) == 'table', 'configuration must be a table')
    assert(input.kind == 'Hinge' or input.kind == 'Ball', 'kind must be Hinge or Ball')
    assert(input.axis == 'X' or input.axis == 'Y' or input.axis == 'Z', 'axis must be X, Y or Z')
    assert(finite(input.lower) and finite(input.upper) and input.lower >= -180 and input.upper <= 180 and input.lower <= input.upper, 'invalid twist/hinge range')
    assert(finite(input.swing) and input.swing >= 0 and input.swing <= 180, 'invalid swing angle')
    return {kind=input.kind, axis=input.axis, lower=input.lower, upper=input.upper, swing=input.swing}
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
