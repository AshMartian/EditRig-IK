local model=Instance.new('Model'); local motor=Instance.new('Motor6D'); motor.Name='Jaw'; motor.Parent=model
local part=Instance.new('Part'); part.Parent=model; local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=part
motor:SetAttribute('EditRigIK_LowerDegrees',-12); bone:SetAttribute('EditRigIK_LowerDegrees',-23)
local settings={kind='Hinge',axis='Z',lower=-30,upper=80,swing=90,control='',impulse='',frequency=4,holdKey='E',reverseHoldKey='R',impulseKey='Q'}
local batch=JointBatch.prepare({motor,bone},settings,Config,InputProfileBuilder)
assert(motor:GetAttribute('EditRigIK_LowerDegrees')==-12 and bone:GetAttribute('EditRigIK_LowerDegrees')==-23,'preparation must not mutate')
JointBatch.apply(batch)
assert(motor:GetAttribute('EditRigIK_LowerDegrees')==-30 and bone:GetAttribute('EditRigIK_LowerDegrees')==-30,'limits must apply to both kinds')
assert(motor:GetAttribute('EditRigIK_Control')=='Jaw' and bone:GetAttribute('EditRigIK_Control')=='Tail','blank names should default per joint')
assert(motor:GetAttribute('EditRigIK_HoldKey')=='E' and bone:GetAttribute('EditRigIK_ImpulseKey')=='Q','keys must persist')
assert(motor:GetAttribute('EditRigIK_ReverseHoldKey')=='R' and bone:GetAttribute('EditRigIK_ReverseHoldKey')=='R','reverse keys must persist')
settings.reverseHoldKey='E'
assert(not pcall(JointBatch.prepare,{motor,bone},settings,Config,InputProfileBuilder),'same key must not be accepted in both directions')
settings.reverseHoldKey='R'
settings.lower=100
assert(not pcall(function() JointBatch.prepare({motor,bone},settings,Config,InputProfileBuilder) end),'invalid limits must be rejected')
assert(motor:GetAttribute('EditRigIK_LowerDegrees')==-30 and bone:GetAttribute('EditRigIK_LowerDegrees')==-30,'failed validation must preserve both joints')
settings.lower=-30
local circularSettings=table.clone(settings); circularSettings.circular={start=-30,width=110}
assert(not pcall(JointBatch.prepare,{motor,bone},circularSettings,Config,InputProfileBuilder), 'batch must reject circular settings until it supports them')
bone:SetAttribute('EditRigIK_SchemaVersion',2)
bone:SetAttribute('EditRigIK_CircularStartDegrees',170); bone:SetAttribute('EditRigIK_CircularWidthDegrees',40)
assert(not pcall(JointBatch.prepare,{motor,bone},settings,Config,InputProfileBuilder), 'batch must reject circular joint metadata')
assert(bone:GetAttribute('EditRigIK_CircularStartDegrees')==170, 'rejected batch preserves circular metadata')
bone:SetAttribute('EditRigIK_SchemaVersion',1)
local changedSchema=JointBatch.prepare({motor,bone},settings,Config,InputProfileBuilder)
bone:SetAttribute('EditRigIK_SchemaVersion',2)
assert(not pcall(JointBatch.apply,changedSchema), 'batch must reject schema changes before writing any joint')
assert(motor:GetAttribute('EditRigIK_LowerDegrees')==-30, 'schema race leaves earlier joint unchanged')
bone:SetAttribute('EditRigIK_SchemaVersion',99)
assert(not pcall(JointBatch.prepare,{motor,bone},settings,Config,InputProfileBuilder), 'unknown schemas must fail closed')
bone:SetAttribute('EditRigIK_SchemaVersion',1)
assert(not pcall(function() JointBatch.prepare({motor,part},settings,Config,InputProfileBuilder) end),'non-joint selection must be rejected')
assert(not pcall(function() JointBatch.prepare({motor,motor},settings,Config,InputProfileBuilder) end),'duplicate joints must be rejected')
local stale=JointBatch.prepare({motor,bone},settings,Config,InputProfileBuilder)
local otherPart=Instance.new('Part'); otherPart.Parent=model; bone.Parent=otherPart
assert(not pcall(function() JointBatch.apply(stale) end),'reparented joints must reject the batch before writes')
assert(motor:GetAttribute('EditRigIK_LowerDegrees')==-30,'stale batch must not update an earlier joint')
settings.holdKey='NotAKey'
assert(not pcall(function() JointBatch.prepare({motor,bone},settings,Config,InputProfileBuilder) end),'invalid key must be rejected')
model:Destroy()
return 'Batch validates all settings before updating Motor6D and Bone joints'
