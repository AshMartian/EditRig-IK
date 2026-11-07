-- Run in a disposable Play-mode server, never in the edit DataModel.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsServer(),'Play server required')
local model=Instance.new('Model'); model.Name='EditRigIKPlayProbe'
local root=Instance.new('Part'); root.Anchored=true; root.Size=Vector3.one; root.CFrame=CFrame.new(0,100,0); root.Parent=model
local tip=Instance.new('Part'); tip.Size=Vector3.one; tip.CanCollide=false; tip.Massless=true; tip.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Hinge'; motor.Part0=root; motor.Part1=tip; motor.C0=CFrame.new(0,1,0); motor.C1=CFrame.new(0,-1,0); motor.Parent=root
local bone=Instance.new('Bone'); bone.Name='Bone'; bone.Parent=root
local animation=Instance.new('AnimationController'); animation.Parent=model
local animator=Instance.new('Animator'); animator.Parent=animation
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
for _,item in ipairs({{'Hinge',motor},{'Bone',bone}}) do
 local ref=Instance.new('ObjectValue'); ref.Name=item[1]; ref.Value=item[2]; ref.Parent=definition
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-90); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control','Move'); ref:SetAttribute('Frequency',4)
end
local dummy=Instance.new('ModuleScript'); dummy.Name='EditRigIKRuntime'
local storage={FindFirstChild=function(_,name) if name=='EditRigIKRuntime' then return dummy end end}
local fakeGame={GetService=function(_,name) if name=='ReplicatedStorage' then return storage elseif name=='RunService' then return run end error('unexpected service') end}
local controller=GeneratedControllerFactory({Parent=model},fakeGame,function(item) assert(item==dummy); return Runtime end)
local message
local ok,result=xpcall(function()
 model.Parent=workspace
 local actor=controller.run({exclusive=true},function(err) message=err end)
 actor:setControl('Move',.5)
 for _=1,5 do run.PostSimulation:Wait() end
 assert(not message,'unexpected runtime conflict: '..tostring(message))
 local expected=CFrame.Angles(0,0,math.pi/4)
 assert(motor.Transform:FuzzyEq(expected,1e-4) and bone.Transform:FuzzyEq(expected,1e-4),'PreSimulation should update Motor6D and Bone transforms')
 local expectedPart=root.CFrame*motor.C0*motor.Transform*motor.C1:Inverse()
 assert((tip.Position-expectedPart.Position).Magnitude<.05,'simulated part should follow Motor6D transform')
 assert(#controller.stop()==0,'owned transforms must restore')
 return 'Play server: PreSimulation drives Motor6D and Bone; simulated part follows; idle Animator present'
end,debug.traceback)
pcall(controller.stop); model:Destroy(); dummy:Destroy()
assert(ok,result)
return result
