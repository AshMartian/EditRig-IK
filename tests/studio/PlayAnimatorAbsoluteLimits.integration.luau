-- Run in a disposable Play server; creates a temporary local animation asset.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsServer(),'Play server required')
local model=Instance.new('Model'); model.Name='EditRigIKAnimatorProbe'
local root=Instance.new('Part'); root.Name='Root'; root.Anchored=true; root.CFrame=CFrame.new(0,110,0); root.Parent=model
local tip=Instance.new('Part'); tip.Name='Tip'; tip.CanCollide=false; tip.Massless=true; tip.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Hinge'; motor.Part0=root; motor.Part1=tip; motor.Parent=root
local animationController=Instance.new('AnimationController'); animationController.Parent=model
local animator=Instance.new('Animator'); animator.Parent=animationController
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
local ref=Instance.new('ObjectValue'); ref.Name='Hinge'; ref.Value=motor; ref.Parent=definition
ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-20); ref:SetAttribute('UpperDegrees',20)
ref:SetAttribute('Control','Move'); ref:SetAttribute('Frequency',4)
local sequence=Instance.new('KeyframeSequence'); sequence.Loop=true
for _,time in ipairs({0,1}) do
 local frame=Instance.new('Keyframe'); frame.Time=time; frame.Parent=sequence
 local parentPose=Instance.new('Pose'); parentPose.Name='Root'; parentPose.Parent=frame
 local childPose=Instance.new('Pose'); childPose.Name='Tip'; childPose.CFrame=CFrame.Angles(0,0,.3); childPose.Parent=parentPose
end
local anim=Instance.new('Animation'); local dummy=Instance.new('ModuleScript'); dummy.Name='EditRigIKRuntime'
local storage={FindFirstChild=function(_,name) if name=='EditRigIKRuntime' then return dummy end end}
local fakeGame={GetService=function(_,name) if name=='ReplicatedStorage' then return storage elseif name=='RunService' then return run end error('unexpected service') end}
local controller=GeneratedControllerFactory({Parent=model},fakeGame,function(item) assert(item==dummy); return Runtime end)
local track
local ok,result=xpcall(function()
 model.Parent=workspace
 anim.AnimationId=game:GetService('KeyframeSequenceProvider'):RegisterKeyframeSequence(sequence)
 track=animator:LoadAnimation(anim); track.Looped=true; track:Play(0)
 for _=1,15 do run.PostSimulation:Wait() end
 assert(not motor.Transform:FuzzyEq(CFrame.identity,1e-4),'temporary Animator track did not produce a joint pose')
 local base=motor.Transform
 local reported
 local actor=controller.run({exclusive=true,baseMode='animated',limitMode='absolute'},function(err) reported=err end)
 actor:setControl('Move',1)
 for _=1,15 do
  run.PostSimulation:Wait()
  assert(not reported,'overlay unexpectedly failed: '..tostring(reported))
  assert(motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(20)),1e-4),'combined pose must respect the absolute hinge limit')
 end
 assert(#controller.stop()==0,'overlay should release without conflict')
 assert(motor.Transform:FuzzyEq(base,1e-4),'overlay stop should restore most recent base')
 return 'Play server: active Animator overlay respected absolute hinge limit and restored the base'
end,debug.traceback)
pcall(controller.stop); if track then track:Stop(0); track:Destroy() end
anim:Destroy(); sequence:Destroy(); dummy:Destroy(); model:Destroy()
assert(ok,result)
return result
