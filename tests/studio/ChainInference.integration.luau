-- ChainInference is supplied by the Studio test harness.
local model=Instance.new('Model')
local function part() local p=Instance.new('Part'); p.Parent=model; return p end
local function motor(a,b) local j=Instance.new('Motor6D'); j.Part0=a; j.Part1=b; j.Parent=model; return j end
local a,b,c,d=part(),part(),part(),part()
local hip=motor(a,b); local knee=motor(b,c)
local tip=Instance.new('Attachment'); tip.Parent=c
local result=ChainInference.infer(model,knee)
assert(result.ok and #result.joints==2 and result.joints[1]==hip and result.joints[2]==knee and result.root==hip and result.endJoint==knee and result.endpoint==tip,'infer ordered Motor6D chain and endpoint')
assert(result.rootSource=='inferred' and result.endpointSource=='inferred')
knee.Enabled=false
assert(not ChainInference.infer(model,knee).ok,'disabled selected joints must be rejected')
knee.Enabled=true
local disconnected=motor(part(),part())
assert(not ChainInference.infer(model,knee,{root=disconnected,endpoint=tip}).ok,'disconnected root must be rejected')
disconnected:Destroy()
local branch=motor(b,d)
local branchTip=Instance.new('Attachment'); branchTip.Parent=d
assert(not ChainInference.infer(model,hip).ok,'branching must not choose a path')
local chosen=ChainInference.infer(model,hip,{root=hip,endpoint=tip})
assert(chosen.ok and #chosen.joints==2 and chosen.joints[2]==knee and chosen.rootSource=='explicit' and chosen.endpointSource=='explicit','explicit endpoints resolve branching')
assert(not ChainInference.infer(model,branch,{root=hip,endpoint=tip}).ok,'explicit path must include the selected joint')
branch:Destroy(); branchTip:Destroy()
local alternate=motor(b,c)
assert(not ChainInference.infer(model,hip,{root=hip,endpoint=tip}).ok,'parallel paths remain ambiguous even with endpoints')
alternate:Destroy()
local loop=motor(c,a)
assert(not ChainInference.infer(model,knee).ok,'cycles must be rejected')
loop:Destroy()
local selfLoop=motor(c,c)
assert(not ChainInference.infer(model,selfLoop,{root=selfLoop,endpoint=tip}).ok,'explicit endpoints must not hide a self-loop')
selfLoop:Destroy()
local external=Instance.new('Part')
local outside=motor(c,external)
assert(not ChainInference.infer(model,knee).ok,'external Motor6D endpoints must not be silently ignored')
outside:Destroy(); external:Destroy()
local broken=motor(c,nil)
assert(not ChainInference.infer(model,knee).ok,'incomplete Motor6D links must not be silently ignored')
broken:Destroy()
local extra=Instance.new('Attachment'); extra.Parent=c
assert(not ChainInference.infer(model,knee).ok,'multiple terminal attachments are ambiguous')
extra:Destroy(); tip:Destroy()
assert(not ChainInference.infer(model,knee).ok,'a missing terminal attachment must be reported')
local boneRoot=Instance.new('Bone'); boneRoot.Parent=a
local boneChild=Instance.new('Bone'); boneChild.Parent=boneRoot
local boneTip=Instance.new('Attachment'); boneTip.Parent=boneChild
assert(not ChainInference.infer(model,boneRoot,{endpoint=boneChild}).ok,'a Bone is not a regular Attachment endpoint')
local bones=ChainInference.infer(model,boneChild)
assert(bones.ok and #bones.joints==2 and bones.joints[1]==boneRoot and bones.joints[2]==boneChild and bones.endpoint==boneTip,'infer ordered Bone chain and attachment')
local boneBranch=Instance.new('Bone'); boneBranch.Parent=boneRoot
local otherTip=Instance.new('Attachment'); otherTip.Parent=boneBranch
assert(not ChainInference.infer(model,boneRoot).ok,'Bone branches are ambiguous')
assert(ChainInference.infer(model,boneRoot,{root=boneRoot,endpoint=boneTip}).ok,'explicit Bone endpoints resolve branching')
assert(not ChainInference.infer(model,boneBranch,{root=boneRoot,endpoint=boneTip}).ok,'disconnected selection is rejected')
local externalModel=Instance.new('Model'); local externalTip=Instance.new('Attachment'); externalTip.Parent=externalModel
assert(not ChainInference.infer(model,boneRoot,{endpoint=externalTip}).ok,'external endpoints are rejected')
assert(not ChainInference.infer(model,boneRoot,{root=hip,endpoint=boneTip}).ok,'mixed joint types are rejected')
model:Destroy(); externalModel:Destroy()
return 'Selected-joint chain inference validates Motor6D and Bone paths'
