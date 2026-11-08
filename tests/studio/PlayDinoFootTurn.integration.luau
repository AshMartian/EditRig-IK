-- Run in a disposable Play server while Workspace.Dino Auto exists.
-- Clones the rig, removes all scripts from the clone before parenting it, and
-- compares its real Transform IKControls at identical turned target positions.
-- Never changes the original rig. This is an orientation diagnostic, not a gait.
local run=game:GetService('RunService')
assert(run:IsRunning() and run:IsServer(),'Play server required')
assert(not workspace:FindFirstChild('EditRigIKDinoFootTurnFixture'),'remove the existing test fixture before retrying')
local template=game:GetService('ReplicatedStorage'):FindFirstChild('DinoAutoBodyRelativeTargetsTemplate')
assert(template and template:IsA('Script') and template.Disabled and template.Archivable,'disabled DinoAutoBodyRelativeTargetsTemplate Script required in ReplicatedStorage')
local source=workspace:FindFirstChild('Dino Auto')
assert(source and source:IsA('Model') and source.Archivable and source.PrimaryPart,'archivable Workspace.Dino Auto with PrimaryPart required')
local rig,fixture,sequence,animation,track,driver
local ok,result=xpcall(function()
 rig=assert(source:Clone(),'could not clone Dino Auto')
 rig.Name='Dino Auto'
 fixture=Instance.new('Folder'); fixture.Name='EditRigIKDinoFootTurnFixture'
 local primary=assert(rig.PrimaryPart,'clone has no PrimaryPart')
 assert(primary==rig:FindFirstChild('HumanoidRootPart'),'fixture requires HumanoidRootPart as PrimaryPart')
 -- Remove active scripts before the copy ever enters Workspace. Existing
 -- Animator and IKControls remain, but no user controller runs on the clone.
 for _,item in ipairs(rig:GetDescendants()) do
  if item:IsA('LuaSourceContainer') then item:Destroy()
  elseif item:IsA('BasePart') then
   item.CanCollide=false; item.CanTouch=false; item.CanQuery=false
   item.AssemblyLinearVelocity=Vector3.zero; item.AssemblyAngularVelocity=Vector3.zero
  end
 end
 local humanoid=rig:FindFirstChildWhichIsA('Humanoid',true)
 assert(humanoid,'clone requires a Humanoid')
 humanoid.AutoRotate=false; humanoid.BreakJointsOnDeath=false
 local animator=humanoid:FindFirstChildOfClass('Animator') or Instance.new('Animator',humanoid)
 local controls={}
 for _,item in ipairs(humanoid:GetDescendants()) do
  if item:IsA('IKControl') and item.Enabled and item.Type==Enum.IKControlType.Transform then
   assert(item.Target and item.Target:IsA('BasePart') and item.Target:IsDescendantOf(rig) and item.Target.Anchored,'expected an anchored target part inside the cloned rig')
   assert(item.EndEffector and item.EndEffector:IsA('BasePart') and item.EndEffector:IsDescendantOf(rig),'expected a cloned BasePart end effector')
   item.Weight=1; item.SmoothTime=0
   table.insert(controls,{ik=item,target=item.Target,foot=item.EndEffector})
  end
 end
 assert(#controls==2,'expected two enabled Transform leg IKControls on the clone')
 -- Anchor only the root; Motor6D-connected parts must remain free to animate.
 for _,item in ipairs(rig:GetDescendants()) do
  if item:IsA('BasePart') then
   local target=false
   for _,entry in ipairs(controls) do if item==entry.target then target=true end end
   item.Anchored=target or item==primary
   item.Massless=item~=primary
  end
 end
 -- Build a static animation tree from the Motor6D graph so Roblox evaluates
 -- the actual cloned IKControls with an active Animator, as in other Play probes.
 local children={}
 for _,item in ipairs(rig:GetDescendants()) do
  if item:IsA('Motor6D') and item.Enabled and item.Part0 and item.Part1 and item.Part0:IsDescendantOf(rig) and item.Part1:IsDescendantOf(rig) then
   local list=children[item.Part0] or {}; children[item.Part0]=list; table.insert(list,item.Part1)
  end
 end
 sequence=Instance.new('KeyframeSequence'); sequence.Loop=true
 for _,time in ipairs({0,1}) do
  local frame=Instance.new('Keyframe'); frame.Time=time; frame.Parent=sequence
  local seen={}
  local function poseFor(part,parent)
   assert(not seen[part],'cyclic or multiply-parented Motor6D graph')
   seen[part]=true
   local pose=Instance.new('Pose'); pose.Name=part.Name; pose.Parent=parent
   for _,child in ipairs(children[part] or {}) do poseFor(child,pose) end
  end
  poseFor(primary,frame)
  for _,entry in ipairs(controls) do assert(seen[entry.foot],'foot is not reachable from the cloned primary part through Motor6Ds') end
 end
 rig:PivotTo(CFrame.new(0,300,0)*rig:GetPivot().Rotation)
 rig.Parent=fixture; fixture.Parent=workspace
 animation=Instance.new('Animation')
 animation.AnimationId=game:GetService('KeyframeSequenceProvider'):RegisterKeyframeSequence(sequence)
 track=animator:LoadAnimation(animation); track.Looped=true; track:Play(0)
 local function settle() for _=1,60 do run.PostSimulation:Wait() end end
 local function separation(a,b) local _,angle=(a.Rotation:Inverse()*b.Rotation):ToAxisAngle(); return math.abs(angle) end
 settle()
 local startBody=primary.CFrame
 for _,entry in ipairs(controls) do entry.startTarget=entry.target.CFrame; entry.startFoot=entry.foot.CFrame end
 local initialPivot=rig:GetPivot()
 local turn=CFrame.Angles(0,math.rad(60),0)
 rig:PivotTo(CFrame.new(initialPivot.Position)*turn*initialPivot.Rotation)
 local turnedBody=primary.CFrame
 assert(math.abs(separation(startBody,turnedBody)-math.rad(60))<.01,'fixture body did not turn 60 degrees')
 -- Both experiments use precisely the same turned target position. Only target
 -- rotation changes; this isolates heading from target reach and pole changes.
 for _,entry in ipairs(controls) do
  entry.turnedPosition=entry.target.Position
  entry.target.CFrame=CFrame.new(entry.turnedPosition)*entry.startTarget.Rotation
 end
 settle()
 for _,entry in ipairs(controls) do entry.fixedFoot=entry.foot.CFrame end
 for _,entry in ipairs(controls) do
  entry.target.CFrame=CFrame.new(entry.turnedPosition)*turn*entry.startTarget.Rotation
 end
 settle()
 local lines={}
 for _,entry in ipairs(controls) do
  local fixedDelta=separation(entry.startFoot,entry.fixedFoot)
  local trackingDelta=separation(entry.startFoot,entry.foot.CFrame)
  local response=separation(entry.fixedFoot,entry.foot.CFrame)
  assert((entry.target.Position-entry.turnedPosition).Magnitude<1e-4,'target position drifted during heading comparison')
  assert(fixedDelta<math.rad(20),entry.ik.Name..': fixed target did not hold approximately fixed foot orientation: '..math.deg(fixedDelta))
  assert(trackingDelta>math.rad(30) and response>math.rad(30),entry.ik.Name..': body-relative target did not rotate the foot sufficiently: '..math.deg(response))
  table.insert(lines,string.format('%s foot rotation: fixed %.1f°, body-relative %.1f°, change %.1f°',entry.ik.Name,math.deg(fixedDelta),math.deg(trackingDelta),math.deg(response)))
 end
 -- Verify the actual disabled template on this sanitized clone. Capture its
 -- initial relative frames before a separate body turn; no target movement is
 -- scripted by the fixture after enabling the driver.
 driver=assert(template:Clone(),'cannot clone target heading template')
 driver.Name='EditRigIKBodyRelativeTargets'; driver.Disabled=true; driver.Parent=rig
 local beforeBody=primary.CFrame
 for _,entry in ipairs(controls) do entry.driverTarget=entry.target.CFrame; entry.driverFoot=entry.foot.CFrame end
 driver.Disabled=false
 settle()
 local driverTurn=CFrame.Angles(0,math.rad(45),0)
 primary.CFrame=CFrame.new(primary.Position)*driverTurn*primary.CFrame.Rotation
 settle()
 assert(math.abs(separation(beforeBody,primary.CFrame)-math.rad(45))<.01,'driver test body did not turn')
 for _,entry in ipairs(controls) do
  local targetTurn=separation(entry.driverTarget,entry.target.CFrame)
  local footTurn=separation(entry.driverFoot,entry.foot.CFrame)
  assert((entry.target.Position-entry.driverTarget.Position).Magnitude<1e-4,'driver changed target position')
  assert(math.abs(targetTurn-math.rad(45))<math.rad(2),'actual template did not rotate '..entry.target.Name..' with the body: '..math.deg(targetTurn))
  assert(footTurn>math.rad(25),'actual template did not turn '..entry.foot.Name..': '..math.deg(footTurn))
  table.insert(lines,string.format('%s template: target %.1f°, foot %.1f°',entry.ik.Name,math.deg(targetTurn),math.deg(footTurn)))
 end
 -- A competing rotation writer must stop the whole experiment rather than
 -- allowing the other target to continue under a partial configuration.
 local altered=controls[1].target
 altered.CFrame=altered.CFrame*CFrame.Angles(0,.25,0)
 for _=1,4 do run.PostSimulation:Wait() end
 local held=controls[2].target.CFrame
 primary.CFrame=CFrame.new(primary.Position)*CFrame.Angles(0,math.rad(20),0)*primary.CFrame.Rotation
 for _=1,20 do run.PostSimulation:Wait() end
 assert(separation(held,controls[2].target.CFrame)<1e-4,'driver continued writing after a target rotation conflict')
 table.insert(lines,'rotation conflict stopped both targets')
 return table.concat(lines,'; ')
end,debug.traceback)
if track then pcall(function() track:Stop(0); track:Destroy() end) end
if animation then animation:Destroy() end
if sequence then sequence:Destroy() end
if rig then rig:Destroy() end
if fixture then fixture:Destroy() end
assert(ok,result)
return result
