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
assert(#result.joints==3 and result.joints[1]==hip and result.joints[2]==knee and result.joints[3]==ankle,'include incoming root motor')
assert(result.endpoint==endpoint and result.pole==pole)
ik.EndEffector=foot
assert(ChainDiscovery.inspect(ik).endpoint==nil,'BasePart end requires explicit endpoint')
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
model:Destroy()
return 'IKControl discovery handles Motor6D and Bone paths'
