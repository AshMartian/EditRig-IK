-- Disposable Play server. Requires a sanitized WORM asset in the temporary sandbox.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsServer(),'Play server required')
local sandbox=game:GetService('ReplicatedStorage'):FindFirstChild('EditRigIKTempAssetSandbox')
local asset=sandbox and sandbox:FindFirstChild('TemporarySkinnedRig')
local source=asset and asset:FindFirstChild('worm'); assert(source and source:IsA('Model'),'temporary skinned source missing')
local clone=source:Clone(); clone.Name='EditRigIKPlaySkinnedProbe'
for _,item in ipairs(clone:GetDescendants()) do
 assert(not item:IsA('LuaSourceContainer'),'fixture must be sanitized before Play')
 if item:IsA('BasePart') then item.Anchored=true; item.CanCollide=false end
end
local mesh=clone:FindFirstChildWhichIsA('MeshPart',true); assert(mesh,'skinned MeshPart missing')
local root=mesh:FindFirstChild('1'); assert(root and root:IsA('Bone'),'root Bone missing')
local bones={}; local current=root
for i=1,15 do
 assert(current and current:IsA('Bone') and current.Name==tostring(i),'Bone chain changed')
 assert(current.Transform:FuzzyEq(CFrame.identity,1e-5),'fixture must start at rest')
 table.insert(bones,current); if i<15 then current=current:FindFirstChild(tostring(i+1)) end
end
local chain,connection=nil,nil
local ok,result=xpcall(function()
 clone.Parent=workspace; clone:PivotTo(CFrame.new(0,150,0))
 game:GetService('ContentProvider'):PreloadAsync({mesh})
 local solver=Solver.new(Limits)
 chain=ChainAdapter.new(bones,Vector3.new(0,1.68,0),{exclusive=true},solver)
 local start=bones[#bones].TransformedWorldCFrame:PointToWorldSpace(Vector3.new(0,1.68,0))
 local target=start+Vector3.new(8,0,-6)
 local latest,problem=nil,nil
 connection=run.PreSimulation:Connect(function(dt)
  local good,value=pcall(function() return chain:solve(target,{iterations=100,tolerance=.05,maxAngularSpeed=math.rad(180),dt=dt}) end)
  if good then latest=value else problem=tostring(value) end
 end)
 for _=1,120 do run.PostSimulation:Wait(); if problem or (latest and latest.converged) then break end end
 assert(not problem,'skinned chain update failed: '..tostring(problem))
 assert(latest and latest.converged,'skinned chain did not converge in the allotted frames')
 local moved=0; for _,bone in ipairs(bones) do if not bone.Transform:FuzzyEq(CFrame.identity,1e-5) then moved+=1 end end
 assert(moved>0,'skinned Bones did not move')
 local endpoint=bones[#bones].TransformedWorldCFrame:PointToWorldSpace(Vector3.new(0,1.68,0))
 assert((endpoint-latest.endpointWorld).Magnitude<1e-3,'reported endpoint must match the animated Bones')
 connection:Disconnect(); connection=nil
 local conflicts=chain:destroy(); chain=nil; assert(#conflicts==0,'owned Bones should restore without conflicts')
 for _,bone in ipairs(bones) do assert(bone.Transform:FuzzyEq(CFrame.identity,1e-5),'Bone did not restore') end
 local sourceMesh=source:FindFirstChildWhichIsA('MeshPart',true)
 for _,bone in ipairs(sourceMesh:GetDescendants()) do if bone:IsA('Bone') then assert(bone.Transform:FuzzyEq(CFrame.identity,1e-5),'source Bone changed') end end
 return string.format('Play server: moved %d skinned Bones, converged with %.5f-stud error, restored owned transforms',moved,latest.error)
end,debug.traceback)
if connection then connection:Disconnect() end
if chain then pcall(function() chain:destroy() end) end
clone:Destroy(); assert(ok,result)
return result
