--!strict
-- The editor calls this module to validate draft settings before saving joint
-- attributes. Limits and control settings are prepared separately so an invalid
-- edit cannot partly write one group of attributes.
local JointAuthoring = {}
local limitNames = {kind='EditRigIK_Kind',axis='EditRigIK_Axis',lower='EditRigIK_LowerDegrees',upper='EditRigIK_UpperDegrees',swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
local circularNames = {start='EditRigIK_CircularStartDegrees',width='EditRigIK_CircularWidthDegrees'}
local driveNames = {control='EditRigIK_Control',impulse='EditRigIK_Impulse',frequency='EditRigIK_Frequency',holdKey='EditRigIK_HoldKey',reverseHoldKey='EditRigIK_ReverseHoldKey',holdValue='EditRigIK_HoldValue',impulseKey='EditRigIK_ImpulseKey',impulseValue='EditRigIK_ImpulseValue'}
local function parentOf(joint)
    assert(typeof(joint)=='Instance' and (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint.Parent, 'select one parented Motor6D or Bone')
    return joint.Parent
end
function JointAuthoring.prepareLimits(joint, input, config)
    local parent = parentOf(joint)
    assert(type(input)=='table' and type(input.weight)=='number', 'enter a joint influence')
    local oldSchema=joint:GetAttribute('EditRigIK_SchemaVersion')
    assert(oldSchema==nil or oldSchema==1 or oldSchema==2, 'unsupported joint metadata schema')
    local values=config.validate(input)
    assert(oldSchema~=2 or values.circular~=nil or input.replaceCircular==true, 'explicitly replace circular limits before switching to legacy limits')
    return {joint=joint, parent=parent, oldSchema=oldSchema, values=values}
end
function JointAuthoring.applyLimits(entry)
    assert(entry.joint.Parent==entry.parent and entry.joint:GetAttribute('EditRigIK_SchemaVersion')==entry.oldSchema, 'joint changed; select it again')
    -- Mark the metadata unsupported while fields change; readers fail closed
    -- during attribute changed callbacks until the final version is written.
    entry.joint:SetAttribute('EditRigIK_SchemaVersion',0)
    for key,name in pairs(limitNames) do entry.joint:SetAttribute(name,entry.values[key]) end
    for key,name in pairs(circularNames) do entry.joint:SetAttribute(name,if entry.values.circular then entry.values.circular[key] else nil) end
    entry.joint:SetAttribute('EditRigIK_SchemaVersion',if entry.values.circular then 2 else 1)
end
function JointAuthoring.prepareDrive(joint, input, config, keys)
    local parent=parentOf(joint)
    local version=joint:GetAttribute('EditRigIK_SchemaVersion')
    assert(version==1 or version==2, 'save valid joint limits before saving controls')
    local saved={}
    for key,name in pairs(limitNames) do saved[key]=joint:GetAttribute(name) end
    if version==2 then
        saved.circular={}
        for key,name in pairs(circularNames) do saved.circular[key]=joint:GetAttribute(name) end
    end
    local valid,limit=pcall(config.validate,saved)
    assert(valid, 'save valid joint limits before saving controls')
    assert(type(input.frequency)=='number', 'enter a damping frequency')
    assert(type(input.holdValue)=='number' and type(input.impulseValue)=='number', 'enter numeric hold and impulse values')
    local drive=config.validateDrive(input,joint.Name)
    local holdKey,reverseHoldKey=keys.validateHoldKeys(input.holdKey,input.reverseHoldKey)
    local impulseKey=keys.validateKey(input.impulseKey)
    local values={control=drive.control,impulse=drive.impulse,frequency=drive.frequency,
        holdKey=holdKey,reverseHoldKey=reverseHoldKey,impulseKey=impulseKey,
        holdValue=keys.validateAmount(limit.kind,'Hold',input.holdValue),
        impulseValue=keys.validateAmount(limit.kind,'Impulse',input.impulseValue)}
    return {joint=joint,parent=parent,kind=limit.kind,schema=version,values=values}
end
function JointAuthoring.applyDrive(entry)
    assert(entry.joint.Parent==entry.parent and entry.joint:GetAttribute('EditRigIK_Kind')==entry.kind and entry.joint:GetAttribute('EditRigIK_SchemaVersion')==entry.schema, 'joint or its saved limit type changed; prepare controls again')
    for key,name in pairs(driveNames) do entry.joint:SetAttribute(name,entry.values[key]) end
end
return JointAuthoring
