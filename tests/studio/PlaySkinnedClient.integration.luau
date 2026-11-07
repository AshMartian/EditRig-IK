-- Disposable Play client. Load Solver, Limits, ChainAdapter and the sanitized WORM asset first.
local run=game:GetService('RunService'); assert(run:IsRunning() and run:IsClient(),'Play client required')
assert(not workspace:FindFirstChild('EditRigIKClientSkinnedProbe'),'client probe already exists')
local sandbox=game:GetService('ReplicatedStorage'):WaitForChild('EditRigIKTempAssetSandbox')
local source=sandbox.TemporarySkinnedRig:FindFirstChild('worm'); assert(source and source:IsA('Model'))
local model=source:Clone(); model.Name='EditRigIKClientSkinnedProbe'
for _,item in ipairs(model:GetDescendants()) do
 assert(not item:IsA('LuaSourceContainer'),'fixture must be sanitized before Play')
 if item:IsA('BasePart') then item.Anchored=true; item.CanCollide=false end
end
local mesh=model:FindFirstChildWhichIsA('MeshPart',true); assert(mesh)
local bone=mesh:FindFirstChild('1'); local bones={}
for i=1,15 do assert(bone and bone:IsA('Bone') and bone.Name==tostring(i)); table.insert(bones,bone); if i<15 then bone=bone:FindFirstChild(tostring(i+1)) end end
local chain,connection
local ok,problem=pcall(function()
 local camera=workspace.CurrentCamera; assert(camera)
 model.Parent=workspace; model:PivotTo(camera.CFrame*CFrame.new(0,0,-24)*CFrame.Angles(0,math.pi/2,0))
 game:GetService('ContentProvider'):PreloadAsync({mesh})
 chain=ChainAdapter.new(bones,Vector3.new(0,1.68,0),{exclusive=true},Solver.new(Limits))
 local rootPosition=bones[1].TransformedWorldCFrame.Position
 local endPosition=bones[#bones].TransformedWorldCFrame:PointToWorldSpace(Vector3.new(0,1.68,0))
 local direction=(endPosition-rootPosition).Unit
 local up=camera.CFrame.UpVector; local sideways=(up-direction*up:Dot(direction)).Unit
 local target=rootPosition+(endPosition-rootPosition)*.75+sideways*8
 local start=Instance.new('BindableEvent'); start.Name='StartSolve'; start.Parent=model
 local stop=Instance.new('BindableFunction'); stop.Name='StopProbe'; stop.Parent=model
 start.Event:Connect(function()
  if connection then return end
  connection=run.PreSimulation:Connect(function(dt)
   local good,result=pcall(function() return chain:solve(target,{iterations=100,tolerance=.05,maxAngularSpeed=math.rad(180),dt=dt}) end)
   if good then model:SetAttribute('Status',result.status); model:SetAttribute('Error',result.error); model:SetAttribute('Converged',result.converged)
   else model:SetAttribute('Problem',tostring(result)); connection:Disconnect(); connection=nil end
  end)
 end)
 stop.OnInvoke=function()
  if connection then connection:Disconnect(); connection=nil end
  local conflicts=chain:destroy(); chain=nil
  local restored=true; for _,item in ipairs(bones) do if not item.Transform:FuzzyEq(CFrame.identity,1e-5) then restored=false end end
  model:Destroy()
  return #conflicts,restored
 end
end)
if not ok then if connection then connection:Disconnect() end; if chain then pcall(function() chain:destroy() end) end; model:Destroy(); error(problem) end
return 'Client-local skinned fixture ready; invoke StartSolve and StopProbe explicitly'
