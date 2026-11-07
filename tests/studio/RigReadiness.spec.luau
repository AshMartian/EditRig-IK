local model=Instance.new('Model'); model.Name='Fixture'
local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Hip'; motor.Part0=a; motor.Part1=b; motor.Parent=a
local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=a
local invalid=Instance.new('Motor6D'); invalid.Name='Broken'; invalid.Enabled=false; invalid.Parent=a
motor:SetAttribute('EditRigIK_SchemaVersion',1); motor:SetAttribute('EditRigIK_Kind','Hinge'); motor:SetAttribute('EditRigIK_Axis','Z')
motor:SetAttribute('EditRigIK_LowerDegrees',-45); motor:SetAttribute('EditRigIK_UpperDegrees',90); motor:SetAttribute('EditRigIK_SwingDegrees',90)
invalid:SetAttribute('EditRigIK_SchemaVersion',2)
local result=RigInspector.inspect(model,Config)
assert(result.configured==1 and result.missingSettings==1 and result.invalidSettings==1,'report valid, missing, and invalid joint metadata')
assert(result.disabledMotors==1 and result.incompleteMotors==1,'report disabled and disconnected motors')
local formatted=RigInspector.format(result)
assert(string.find(formatted,'Tail',1,true) and string.find(formatted,'Broken',1,true),'issue names must be visible')
assert(motor:GetAttribute('EditRigIK_LowerDegrees')==-45 and bone:GetAttribute('EditRigIK_SchemaVersion')==nil,'inspection must not modify joints')
model:Destroy()
return 'Rig inspection reports metadata readiness and motor problems without changes'
