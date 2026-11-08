assert(JointAuthoring and Config and InputProfileBuilder, 'joint authoring dependencies required')
local parent = Instance.new('Part')
for _, class in ipairs({'Motor6D', 'Bone'}) do
    local joint = Instance.new(class); joint.Name = 'Leg'; joint.Parent = parent
    joint:SetAttribute('EditRigIK_Control', 'OriginalControl')
    joint:SetAttribute('EditRigIK_HoldKey', 'Q')
    local limits = {kind='Hinge', axis='Y', lower=-60, upper=20, swing=70, weight=.75}
    local prepared = JointAuthoring.prepareLimits(joint, limits, Config)
    assert(joint:GetAttribute('EditRigIK_Kind') == nil, 'prepare does not write')
    JointAuthoring.applyLimits(prepared)
    assert(joint:GetAttribute('EditRigIK_LowerDegrees') == -60 and joint:GetAttribute('EditRigIK_SchemaVersion') == 1, 'limits and schema saved')
    assert(joint:GetAttribute('EditRigIK_Control') == 'OriginalControl' and joint:GetAttribute('EditRigIK_HoldKey') == 'Q', 'saving limits preserves control metadata')
    assert(not pcall(JointAuthoring.prepareLimits, joint, {kind='Hinge',axis='X',lower=10,upper=-10,swing=90,weight=1}, Config), 'invalid range rejected')
    assert(joint:GetAttribute('EditRigIK_LowerDegrees') == -60, 'invalid limit never partially writes')
    assert(not pcall(JointAuthoring.prepareLimits, joint, {kind='Hinge',axis='X',lower=-10,upper=10,swing=90}, Config), 'blank influence is rejected rather than silently reset to a default')
    local circular={kind='Hinge',axis='Y',lower=170,upper=-150,swing=70,weight=.75,circular={start=170,width=40}}
    local circleEntry=JointAuthoring.prepareLimits(joint,circular,Config)
    assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1, 'preparing circular limits does not write')
    local staleVersion=JointAuthoring.prepareLimits(joint,circular,Config)
    joint:SetAttribute('EditRigIK_SchemaVersion',99)
    assert(not pcall(JointAuthoring.applyLimits,staleVersion), 'schema changes invalidate a prepared edit')
    joint:SetAttribute('EditRigIK_SchemaVersion',1)
    JointAuthoring.applyLimits(circleEntry)
    assert(joint:GetAttribute('EditRigIK_SchemaVersion')==2, 'circular joint schema must reject old schema readers')
    assert(joint:GetAttribute('EditRigIK_CircularStartDegrees')==170 and joint:GetAttribute('EditRigIK_CircularWidthDegrees')==40, 'circular range persists its positive sweep across the seam')
    assert(joint:GetAttribute('EditRigIK_Control')=='OriginalControl', 'circular authoring preserves controls')
    local circularDrive={control='Circle',impulse='Nudge',frequency=4,holdKey='E',reverseHoldKey='Q',impulseKey='R',holdValue=.5,impulseValue=1}
    local circleDrive=JointAuthoring.prepareDrive(joint,circularDrive,Config,InputProfileBuilder)
    JointAuthoring.applyDrive(circleDrive)
    assert(joint:GetAttribute('EditRigIK_Control')=='Circle', 'controls can be authored against circular joint metadata')
    joint:SetAttribute('EditRigIK_Control','OriginalControl')
    assert(not pcall(JointAuthoring.prepareLimits,joint,limits,Config), 'circular metadata cannot be silently replaced by a legacy editor')
    local bad=table.clone(circular); bad.circular={start=0,width=361}
    assert(not pcall(JointAuthoring.prepareLimits,joint,bad,Config), 'more than one revolution is invalid')
    bad.circular={start=0,width=-1}
    assert(not pcall(JointAuthoring.prepareLimits,joint,bad,Config), 'negative width is invalid')
    bad.circular={start=0/0,width=10}
    assert(not pcall(JointAuthoring.prepareLimits,joint,bad,Config), 'non-finite starts are invalid')
    bad.kind='Ball'; bad.circular={start=0,width=10}
    assert(not pcall(JointAuthoring.prepareLimits,joint,bad,Config), 'circular intervals are hinge-only')
    assert(joint:GetAttribute('EditRigIK_CircularStartDegrees')==170, 'failed validation does not mutate saved limits')
    local replacement=table.clone(limits); replacement.replaceCircular=true
    JointAuthoring.applyLimits(JointAuthoring.prepareLimits(joint,replacement,Config))
    assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1 and joint:GetAttribute('EditRigIK_CircularStartDegrees')==nil and joint:GetAttribute('EditRigIK_CircularWidthDegrees')==nil, 'explicit replacement clears circular metadata')
    local settings={control='Bend',impulse='Nudge',frequency=4,holdKey='E',reverseHoldKey='Q',impulseKey='R',holdValue=.5,impulseValue=1}
    local drive=JointAuthoring.prepareDrive(joint, settings, Config, InputProfileBuilder)
    JointAuthoring.applyDrive(drive)
    assert(joint:GetAttribute('EditRigIK_Control') == 'Bend' and joint:GetAttribute('EditRigIK_ReverseHoldKey') == 'Q', 'control and bindings saved')
    assert(joint:GetAttribute('EditRigIK_LowerDegrees') == -60 and joint:GetAttribute('EditRigIK_Axis') == 'Y', 'saving controls preserves limits')
    settings.holdValue=2
    assert(not pcall(JointAuthoring.prepareDrive,joint,settings,Config,InputProfileBuilder), 'invalid binding rejected')
    assert(joint:GetAttribute('EditRigIK_Control') == 'Bend', 'invalid binding never partially writes')
    settings.holdValue=nil
    assert(not pcall(JointAuthoring.prepareDrive,joint,settings,Config,InputProfileBuilder), 'blank binding amount is rejected')
    settings.holdValue=.5
    local staleDrive=JointAuthoring.prepareDrive(joint,settings,Config,InputProfileBuilder)
    joint:SetAttribute('EditRigIK_Kind','Ball')
    assert(not pcall(JointAuthoring.applyDrive,staleDrive), 'changing the saved joint type invalidates prepared control settings')
    joint:SetAttribute('EditRigIK_Kind','Hinge')
    local stale=JointAuthoring.prepareLimits(joint,limits,Config); joint.Parent=nil
    assert(not pcall(JointAuthoring.applyLimits,stale), 'reparented joint is rejected before writing')
    joint:Destroy()
end
local missing=Instance.new('Motor6D'); missing.Parent=parent
assert(not pcall(JointAuthoring.prepareDrive,missing,{},Config,InputProfileBuilder), 'control authoring requires saved valid limits')
parent:Destroy()
return 'Limit and control authoring independently validates and preserves metadata'
