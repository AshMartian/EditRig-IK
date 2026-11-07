local model=Instance.new('Model'); local body=Instance.new('Part'); body.Parent=model
local upper=Instance.new('Part'); upper.Parent=model; local endPart=Instance.new('Part'); endPart.Parent=model
local hip=Instance.new('Motor6D'); hip.Name='Hip'; hip.Part0=body; hip.Part1=upper; hip.Parent=body
local knee=Instance.new('Motor6D'); knee.Name='Knee'; knee.Part0=upper; knee.Part1=endPart; knee.Parent=upper
local humanoid=Instance.new('Humanoid'); humanoid.Parent=model
local ik=Instance.new('IKControl'); ik.ChainRoot=upper; ik.EndEffector=endPart; ik.Parent=humanoid
local capture=ChainDiscovery.inspect(ik)
local stable=ChainDiscovery.verifyCapture(ik,capture)
local settings={kind='Hinge',axis='Z',lower=-45,upper=90,swing=90,weight=1,control='',impulse='',frequency=4,holdKey='',impulseKey=''}
local entries=JointBatch.prepare(stable,settings,Config,InputProfileBuilder)
assert(hip:GetAttribute('EditRigIK_SchemaVersion')==nil and knee:GetAttribute('EditRigIK_SchemaVersion')==nil,'preparation must not modify rig')
JointBatch.apply(entries)
assert(hip:GetAttribute('EditRigIK_Axis')=='Z' and knee:GetAttribute('EditRigIK_Axis')=='Z' and ik.Enabled,'captured joints should receive settings without changing IKControl')
local alternate=Instance.new('Motor6D'); alternate.Part0=upper; alternate.Part1=endPart; alternate.Parent=upper
assert(not pcall(function() ChainDiscovery.verifyCapture(ik,capture) end),'changed ambiguous path must be rejected')
alternate:Destroy(); ik.EndEffector=upper
assert(not pcall(function() ChainDiscovery.verifyCapture(ik,capture) end),'changed chain must require recapture')
local root=Instance.new('Bone'); root.Parent=body; local child=Instance.new('Bone'); child.Parent=root
ik.ChainRoot=root; ik.EndEffector=child
local bones=ChainDiscovery.inspect(ik)
local verified=ChainDiscovery.verifyCapture(ik,bones)
JointBatch.apply(JointBatch.prepare(verified,settings,Config,InputProfileBuilder))
assert(root:GetAttribute('EditRigIK_Axis')=='Z' and child:GetAttribute('EditRigIK_Axis')=='Z','Bone chains should support captured settings')
model:Destroy()
return 'Captured IKControl chains validate before batch Motor6D and Bone authoring'
