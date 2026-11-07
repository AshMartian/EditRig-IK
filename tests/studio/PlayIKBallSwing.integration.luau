-- Run on a disposable Play server. Load IKConstraintBuilder and Config first.
-- Each axis and direction starts with a fresh rig.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsServer(),'Play server required')
local results={}
for _,case in ipairs({
 {axis=Vector3.xAxis,link=Vector3.yAxis,name='X'},
 {axis=Vector3.yAxis,link=Vector3.xAxis,name='Y'},
 {axis=Vector3.zAxis,link=Vector3.xAxis,name='Z'},
}) do
 for _,direction in ipairs({1,-1}) do
  local rig=Instance.new('Model'); rig.Name='EditRigIKAxisProbe'
  local origin=Vector3.new(0,120,0); local side=case.axis:Cross(case.link)*direction
  local function part(name,position,anchored)
   local p=Instance.new('Part'); p.Name=name; p.Size=Vector3.new(.2,.2,.2); p.CanCollide=false
   p.Massless=not anchored; p.Anchored=anchored; p.Position=position; p.Parent=rig; return p
  end
  local base=part('Base',origin,true); local upper=part('Upper',origin,false)
  local mid=part('Mid',origin+case.link,false); local lower=part('Lower',origin+case.link*2,false)
  local target=part('Target',origin+case.link+side*.4,true)
  local function joint(a,b,name,offset)
   local j=Instance.new('Motor6D'); j.Name=name; j.Part0=a; j.Part1=b; j.C0=CFrame.new(offset); j.Parent=a; return j
  end
  joint(base,upper,'Root',Vector3.zero); local elbow=joint(upper,mid,'Elbow',case.link); joint(mid,lower,'Tip',case.link)
  local ac=Instance.new('AnimationController'); ac.Parent=rig; local animator=Instance.new('Animator'); animator.Parent=ac
  local ik=Instance.new('IKControl'); ik.Type=Enum.IKControlType.Position; ik.ChainRoot=upper; ik.EndEffector=lower; ik.Target=target; ik.SmoothTime=0; ik.Parent=ac
  elbow:SetAttribute('EditRigIK_SchemaVersion',1); elbow:SetAttribute('EditRigIK_Kind','Ball'); elbow:SetAttribute('EditRigIK_Axis',if case.link==Vector3.yAxis then 'Y' else 'X')
  elbow:SetAttribute('EditRigIK_LowerDegrees',-180); elbow:SetAttribute('EditRigIK_UpperDegrees',180); elbow:SetAttribute('EditRigIK_SwingDegrees',20)
  local builder=IKConstraintBuilder.new(Config); local hinge=builder.apply(builder.prepare(elbow)); hinge.Enabled=false
  local sequence=Instance.new('KeyframeSequence'); sequence.Loop=true
  for _,time in ipairs({0,1}) do
   local key=Instance.new('Keyframe'); key.Time=time; key.Parent=sequence
   local pose=Instance.new('Pose'); pose.Name='Base'; pose.Parent=key
   for _,name in ipairs({'Upper','Mid','Lower'}) do local child=Instance.new('Pose'); child.Name=name; child.Parent=pose; pose=child end
  end
  local animation=Instance.new('Animation'); local track
  local ok,result=xpcall(function()
   rig.Parent=workspace; animation.AnimationId=game:GetService('KeyframeSequenceProvider'):RegisterKeyframeSequence(sequence)
   track=animator:LoadAnimation(animation); track.Looped=true; track:Play(0)
   local function measure()
    for _=1,45 do run.PostSimulation:Wait() end
    assert(ik:GetChainCount()>=2,'IK chain was not built')
    local relative=ik:GetNodeWorldCFrame(1):Inverse()*ik:GetNodeWorldCFrame(2)
    local axis,angle=relative:ToAxisAngle()
    return math.deg(angle*axis:Dot(case.axis))
   end
   local free=measure(); hinge.Enabled=true; local limited=measure()
   assert(math.abs(free)>45,'unconstrained pose must bend enough to test limits')
   assert(math.abs(math.abs(limited)-20)<1,'generated ball must constrain swing to 20 degrees')
   return string.format('%s direction %+d: free=%+.2f limited=%+.2f degrees',case.name,direction,free,limited)
  end,debug.traceback)
  if track then track:Stop(0); track:Destroy() end
  animation:Destroy(); sequence:Destroy(); rig:Destroy(); assert(ok,result); table.insert(results,result)
 end
end
return table.concat(results,'\n')
