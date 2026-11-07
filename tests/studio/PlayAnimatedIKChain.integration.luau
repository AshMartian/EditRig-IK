-- Disposable Play server with an active temporary Animator track.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsServer(),'Play server required')
local model=Instance.new('Model'); model.Name='EditRigIKAnimatedChainProbe'
local root=Instance.new('Part'); root.Name='Root'; root.Anchored=true; root.CFrame=CFrame.new(0,120,0); root.Parent=model
local tip=Instance.new('Part'); tip.Name='Tip'; tip.CanCollide=false; tip.Massless=true; tip.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Joint'; motor.Part0=root; motor.Part1=tip; motor.Parent=root
local controller=Instance.new('AnimationController'); controller.Parent=model
local animator=Instance.new('Animator'); animator.Parent=controller
local sequence=Instance.new('KeyframeSequence'); sequence.Loop=true
for _,time in ipairs({0,1}) do
 local key=Instance.new('Keyframe'); key.Time=time; key.Parent=sequence
 local parent=Instance.new('Pose'); parent.Name='Root'; parent.Parent=key
 local pose=Instance.new('Pose'); pose.Name='Tip'; pose.CFrame=CFrame.Angles(0,0,-.3); pose.Parent=parent
end
local animation=Instance.new('Animation'); local track,chain,connection
local ok,result=xpcall(function()
 model.Parent=workspace; animation.AnimationId=game:GetService('KeyframeSequenceProvider'):RegisterKeyframeSequence(sequence)
 track=animator:LoadAnimation(animation); track.Looped=true; track:Play(0)
 for _=1,15 do run.PostSimulation:Wait() end
 local base=motor.Transform; assert(not base:FuzzyEq(CFrame.identity,1e-4),'Animator did not write the joint')
 chain=ChainAdapter.new({motor},Vector3.xAxis,{exclusive=true,baseMode='animated'},Solver.new(Limits))
 local target=root.Position+Vector3.yAxis; local problem; local latest
 connection=run.PreSimulation:Connect(function()
  local good,value=pcall(function() return chain:solve(target,{iterations=10,tolerance=.001}) end)
  if good then latest=value else problem=tostring(value) end
 end)
 for _=1,20 do
  run.PostSimulation:Wait()
  assert(not problem,'animated chain failed: '..tostring(problem))
  assert(latest and latest.converged,'animated chain should converge')
  assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-4),'Animator and IK result should remain stable')
 end
 connection:Disconnect(); connection=nil
 assert(#chain:destroy()==0,'animated chain should release cleanly'); chain=nil
 assert(motor.Transform:FuzzyEq(base,1e-4),'cleanup must restore the latest animated base')
 return 'Play server: active Animator and animated-base Motor6D IK remained stable and restored the base'
end,debug.traceback)
if connection then connection:Disconnect() end; if chain then pcall(function() chain:destroy() end) end
if track then track:Stop(0); track:Destroy() end
animation:Destroy(); sequence:Destroy(); model:Destroy(); assert(ok,result)
return result
