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
return Config
