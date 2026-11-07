local model=Instance.new('Model'); model.Name='Fixture'
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local humanoid=Instance.new('Humanoid'); humanoid.Parent=model
local animator=Instance.new('Animator'); animator.Parent=humanoid
local ik=Instance.new('IKControl'); ik.Name='ActiveLeg'; ik.Enabled=true; ik.Parent=humanoid
local inactive=Instance.new('IKControl'); inactive.Name='Inactive'; inactive.Enabled=false; inactive.Parent=humanoid
local result=RigInspector.inspect(model)
assert(result.motors==1 and result.bones==1 and result.animators==1)
assert(#result.ikControls==2 and result.enabledIK==1)
local text=RigInspector.format(result)
assert(string.find(text,'ActiveLeg',1,true) and string.find(text,'enabled',1,true))
assert(string.find(text,'Inactive',1,true) and string.find(text,'disabled',1,true))
assert(string.find(text,'does not prove',1,true),'inspection must not imply ownership is safe')
assert(not pcall(function() RigInspector.inspect(part) end))
model:Destroy()
return 'Rig inspector reports joints and potential animation writers'
