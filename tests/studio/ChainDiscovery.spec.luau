local model=Instance.new('Model')
local body=Instance.new('Part'); body.Parent=model
local upper=Instance.new('Part'); upper.Parent=model
local lower=Instance.new('Part'); lower.Parent=model
local foot=Instance.new('Part'); foot.Parent=model
local hip=Instance.new('Motor6D'); hip.Part0=body; hip.Part1=upper; hip.Parent=body
local knee=Instance.new('Motor6D'); knee.Part0=upper; knee.Part1=lower; knee.Parent=upper
local ankle=Instance.new('Motor6D'); ankle.Part0=lower; ankle.Part1=foot; ankle.Parent=lower
local endpoint=Instance.new('Attachment'); endpoint.Parent=foot
local pole=Instance.new('Attachment'); pole.Parent=body
local humanoid=Instance.new('Humanoid'); humanoid.Parent=model
local ik=Instance.new('IKControl'); ik.ChainRoot=upper; ik.EndEffector=endpoint; ik.Pole=pole; ik.Parent=humanoid
local result=ChainDiscovery.inspect(ik)
assert(ChainDiscovery.parseOffset(' 1, -2.5, 3 ') == Vector3.new(1,-2.5,3))
local moved=Vector3.new(1.2345678, -0.00000012, 12345.678)
assert(ChainDiscovery.parseOffset(ChainDiscovery.formatOffset(moved)) == moved, 'dragged offsets must round-trip without a target jump')
assert(not pcall(function() ChainDiscovery.parseOffset('0,0') end),'incomplete offset must fail clearly')
assert(#result.joints==3 and result.joints[1]==hip and result.joints[2]==knee and result.joints[3]==ankle,'include incoming root motor')
assert(result.endpoint==endpoint and result.pole==pole)
ik.EndEffector=foot
assert(ChainDiscovery.inspect(ik).endpoint==nil,'BasePart end requires explicit endpoint')
local created,parent=ChainDiscovery.prepareEndpoint(ankle,Vector3.new(0,-.5,0))
assert(created.Parent==nil and parent==foot and created.Position==Vector3.new(0,-.5,0),'endpoint must be staged at requested local offset')
assert(not foot:FindFirstChild('EditRigIKEndpoint'),'preparation must not modify the rig')
created.Parent=foot
assert(not pcall(function() ChainDiscovery.prepareEndpoint(ankle,Vector3.new(0,-.5,0)) end),'existing endpoint name must not be overwritten')
created:Destroy()
assert(not pcall(function() ChainDiscovery.prepareEndpoint(ankle,Vector3.zero) end),'zero-length terminal link must be rejected')
ankle.C1=CFrame.new(0,.5,0)
local center=ChainDiscovery.prepareEndpoint(ankle,Vector3.zero)
assert(center.Position==Vector3.zero,'part center is valid when joint is offset from center')
center:Destroy(); ankle.C1=CFrame.identity
local alternate=Instance.new('Motor6D'); alternate.Part0=upper; alternate.Part1=lower; alternate.Parent=upper
assert(not pcall(function() ChainDiscovery.inspect(ik) end),'ambiguous paths must be rejected')
alternate:Destroy()
local secondHip=Instance.new('Motor6D'); secondHip.Part0=body; secondHip.Part1=upper; secondHip.Parent=body
assert(not pcall(function() ChainDiscovery.inspect(ik) end),'ambiguous incoming root must be rejected')
secondHip:Destroy()
knee.Enabled=false
assert(not pcall(function() ChainDiscovery.inspect(ik) end),'disabled joints must not form a path')
knee.Enabled=true
local root=Instance.new('Bone'); root.Parent=body
local child=Instance.new('Bone'); child.Parent=root
local boneTip=Instance.new('Attachment'); boneTip.Parent=child
ik.ChainRoot=root; ik.EndEffector=boneTip
local bones=ChainDiscovery.inspect(ik)
assert(#bones.joints==2 and bones.joints[1]==root and bones.joints[2]==child and bones.endpoint==boneTip,'Bone chain must be discovered')
local boneEndpoint,boneParent=ChainDiscovery.prepareEndpoint(child,Vector3.new(0,0,1))
assert(boneEndpoint.Parent==nil and boneParent==child,'Bone endpoint must be staged on final Bone')
boneEndpoint:Destroy()
assert(not pcall(function() ChainDiscovery.prepareEndpoint(child,Vector3.zero) end),'zero-length Bone endpoint must be rejected')
model:Destroy()
return 'IKControl discovery handles Motor6D and Bone paths'
