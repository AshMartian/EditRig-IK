-- Run only in a disposable Play server. Angle-range observations are diagnostic.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsServer(),'Play server required')
local rig=Instance.new('Model'); rig.Name='EditRigIKConstraintProbe'
local function part(name,x)
 local p=Instance.new('Part'); p.Name=name; p.Size=Vector3.new(.2,.2,.2); p.CanCollide=false
 p.Massless=name~='Base'; p.Anchored=name=='Base'; p.CFrame=CFrame.new(x,120,0); p.Parent=rig; return p
end
local base=part('Base',0); local upper=part('Upper',0); local mid=part('Mid',1); local lower=part('Lower',2)
local function joint(a,b,name,offset)
 local j=Instance.new('Motor6D'); j.Name=name; j.Part0=a; j.Part1=b; j.C0=CFrame.new(offset,0,0); j.Parent=a; return j
end
joint(base,upper,'Root',0); local elbow=joint(upper,mid,'Elbow',1); joint(mid,lower,'Tip',1)
local target=part('Target',1); target.Anchored=true; target.Position=Vector3.new(1,121,0)
local ac=Instance.new('AnimationController'); ac.Parent=rig; local animator=Instance.new('Animator'); animator.Parent=ac
local ik=Instance.new('IKControl'); ik.Type=Enum.IKControlType.Position; ik.ChainRoot=upper; ik.EndEffector=lower; ik.Target=target; ik.SmoothTime=0; ik.Parent=ac
local a0=Instance.new('Attachment'); a0.CFrame=elbow.C0*CFrame.Angles(0,-math.pi/2,0); a0.Parent=upper
local a1=Instance.new('Attachment'); a1.CFrame=elbow.C1*CFrame.Angles(0,-math.pi/2,0); a1.Parent=mid
local hinge=Instance.new('HingeConstraint'); hinge.Attachment0=a0; hinge.Attachment1=a1
hinge.LimitsEnabled=true; hinge.LowerAngle=0; hinge.UpperAngle=0; hinge.Enabled=false; hinge.Parent=mid
local sequence=Instance.new('KeyframeSequence'); sequence.Loop=true
for _,time in ipairs({0,1}) do
 local key=Instance.new('Keyframe'); key.Time=time; key.Parent=sequence
 local pose=Instance.new('Pose'); pose.Name='Base'; pose.Parent=key
 for _,name in ipairs({'Upper','Mid','Lower'}) do local child=Instance.new('Pose'); child.Name=name; child.Parent=pose; pose=child end
end
local anim=Instance.new('Animation'); local track
local ok,result=xpcall(function()
 rig.Parent=workspace; anim.AnimationId=game:GetService('KeyframeSequenceProvider'):RegisterKeyframeSequence(sequence)
 track=animator:LoadAnimation(anim); track.Looped=true; track:Play(0)
 local function observe()
  for _=1,60 do run.PostSimulation:Wait() end
  local relative=ik:GetNodeWorldCFrame(1):Inverse()*ik:GetNodeWorldCFrame(2)
  local _,angle=relative:ToAxisAngle()
  return ik:GetChainCount(),angle,ik:GetNodeWorldCFrame(3).Position
 end
 local n0,before,p0=observe(); hinge.Enabled=true; local n1,after,p1=observe()
 assert(n0>=2 and n1>=2 and before>1 and after<.05,'zero-angle hinge did not constrain the observed bend')
 hinge.Enabled=false; observe(); hinge.LowerAngle=-30; hinge.UpperAngle=30; hinge.Enabled=true
 local _,wide,p2=observe()
 return string.format('nodes=%d/%d bend radians: free=%.4f zero=%.4f plus/minus30=%.4f; endpoint=%s -> %s -> %s',n0,n1,before,after,wide,tostring(p0),tostring(p1),tostring(p2))
end,debug.traceback)
if track then track:Stop(0); track:Destroy() end
anim:Destroy(); sequence:Destroy(); rig:Destroy(); assert(ok,result)
return result
