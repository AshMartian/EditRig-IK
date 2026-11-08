--!strict
-- Prepare each independent metadata edit before touching the selected joint.
local JointAuthoring = {}
local limitNames = {kind='EditRigIK_Kind',axis='EditRigIK_Axis',lower='EditRigIK_LowerDegrees',upper='EditRigIK_UpperDegrees',swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
local driveNames = {control='EditRigIK_Control',impulse='EditRigIK_Impulse',frequency='EditRigIK_Frequency',holdKey='EditRigIK_HoldKey',reverseHoldKey='EditRigIK_ReverseHoldKey',holdValue='EditRigIK_HoldValue',impulseKey='EditRigIK_ImpulseKey',impulseValue='EditRigIK_ImpulseValue'}
local function parentOf(joint)
    assert(typeof(joint)=='Instance' and (joint:IsA('Motor6D') or joint:IsA('Bone')) and joint.Parent, 'select one parented Motor6D or Bone')
    return joint.Parent
end
function JointAuthoring.prepareLimits(joint, input, config)
    local parent = parentOf(joint)
    assert(type(input)=='table' and type(input.weight)=='number', 'enter a joint influence')
    return {joint=joint, parent=parent, values=config.validate(input)}
end
function JointAuthoring.applyLimits(entry)
    assert(entry.joint.Parent==entry.parent, 'joint changed; select it again')
    for key,name in pairs(limitNames) do entry.joint:SetAttribute(name,entry.values[key]) end
    entry.joint:SetAttribute('EditRigIK_SchemaVersion',1)
end
function JointAuthoring.prepareDrive(joint, input, config, keys)
    local parent=parentOf(joint)
    assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1, 'save valid joint limits before saving controls')
    local saved={}
    for key,name in pairs(limitNames) do saved[key]=joint:GetAttribute(name) end
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
    return {joint=joint,parent=parent,kind=limit.kind,values=values}
end
function JointAuthoring.applyDrive(entry)
    assert(entry.joint.Parent==entry.parent and entry.joint:GetAttribute('EditRigIK_Kind')==entry.kind, 'joint or its saved limit type changed; prepare controls again')
    for key,name in pairs(driveNames) do entry.joint:SetAttribute(name,entry.values[key]) end
end
return JointAuthoring
