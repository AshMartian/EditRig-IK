local model=Instance.new('Model'); model.Name='Fixture'
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local humanoid=Instance.new('Humanoid'); humanoid.Parent=model
local animator=Instance.new('Animator'); animator.Parent=humanoid
local ik=Instance.new('IKControl'); ik.Name='ActiveLeg'; ik.Enabled=true; ik.Parent=humanoid
local inactive=Instance.new('IKControl'); inactive.Name='Inactive'; inactive.Enabled=false; inactive.Parent=humanoid
local result=RigInspector.inspect(model,Config)
assert(result.motors==1 and result.bones==1 and result.animators==1)
assert(#result.ikControls==2 and result.enabledIK==1)
assert(result.hingeConstraints==0 and result.ballConstraints==0,'must count mechanical limit types')
assert(result.ikControls[1].hasPole==false,'must report missing edit-time poles')
local text=RigInspector.format(result)
assert(string.find(text,'ActiveLeg',1,true) and string.find(text,'enabled',1,true))
assert(string.find(text,'Inactive',1,true) and string.find(text,'disabled',1,true))
assert(string.find(text,'does not prove',1,true),'inspection must not imply ownership is safe')
assert(string.find(text,'metadata does not constrain',1,true),'inspection must distinguish metadata from built-in IK constraints')
assert(string.find(text,'no pole',1,true),'missing pole must be visible')
local hinge=Instance.new('HingeConstraint'); hinge.Parent=model
local ball=Instance.new('BallSocketConstraint'); ball.Parent=model
local pole=Instance.new('Attachment'); pole.Parent=part; ik.Pole=pole
local updated=RigInspector.inspect(model,Config)
assert(updated.hingeConstraints==1 and updated.ballConstraints==1,'must count both constraint types')
local active
for _,entry in ipairs(updated.ikControls) do if entry.path==ik:GetFullName() then active=entry end end
assert(active and active.hasPole,'assigned pole must be reported')
assert(string.find(RigInspector.format(updated),'not proof',1,true),'constraint counts must not imply they are configured correctly')
assert(not pcall(function() RigInspector.inspect(part,Config) end))
model:Destroy()
return 'Rig inspector reports joints and potential animation writers'
