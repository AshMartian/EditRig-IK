local model=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model
local c=Instance.new('Part'); c.Parent=model
local j1=Instance.new('Motor6D'); j1.Part0=a; j1.Part1=b; j1.Parent=a
local j2=Instance.new('Motor6D'); j2.Part0=b; j2.Part1=c; j2.C0=CFrame.new(1,0,0); j2.Parent=b
local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.new(1,0,0); endpoint.Parent=c
for _,j in ipairs({j1,j2}) do
 j:SetAttribute('EditRigIK_SchemaVersion',1); j:SetAttribute('EditRigIK_Kind','Hinge'); j:SetAttribute('EditRigIK_Axis','Z')
 j:SetAttribute('EditRigIK_LowerDegrees',-180); j:SetAttribute('EditRigIK_UpperDegrees',180); j:SetAttribute('EditRigIK_SwingDegrees',90)
end
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local definition=ChainBuilder.new(Config).create(model,j1,j2,endpoint,'Leg',{iterations=48,tolerance=0.02,maxStepDegrees=20}); definition.Parent=folder
assert(definition:GetAttribute('MaxStepDegrees')==20,'authored correction angle must persist')
local captured
local optionsChain=ChainDefinition.new(definition,{exclusive=true},function()
 return {solve=function(_,_,options) captured=options; return options end,destroy=function() return {} end}
end)
optionsChain:solve(Vector3.zero,{iterations=7})
assert(captured.iterations==7 and captured.tolerance==0.02 and math.abs(captured.maxStep-math.rad(20))<1e-8,'partial override must preserve saved settings')
optionsChain:solve(Vector3.zero,{maxStep=math.rad(10)})
assert(math.abs(captured.maxStep-math.rad(10))<1e-8 and captured.iterations==48,'runtime correction angle override must reach solver')
optionsChain:solve(Vector3.zero,{tolerance=0})
assert(captured.iterations==48 and captured.tolerance==0,'partial override must preserve saved iterations and accept zero tolerance')
ChainBuilder.new(Config).writeSettings(definition,{iterations=12,tolerance=.05,maxStepDegrees=30})
optionsChain:solve(Vector3.zero)
assert(captured.iterations==48,'an open chain keeps its original snapshot')
local reopened=ChainDefinition.new(definition,{exclusive=true},function()
 return {solve=function(_,_,options) captured=options; return options end,destroy=function() return {} end}
end)
reopened:solve(Vector3.zero)
assert(captured.iterations==12 and captured.tolerance==.05 and math.abs(captured.maxStep-math.rad(30))<1e-8,'reopened chain must use updated settings')
reopened:destroy()
ChainBuilder.new(Config).writeSettings(definition,{iterations=48,tolerance=.02,maxStepDegrees=20})
assert(not pcall(function() optionsChain:solve(Vector3.zero,{iteration=7}) end),'unknown options must not be ignored')
assert(not pcall(function() optionsChain:solve(Vector3.zero,false) end),'invalid override type must be rejected')
optionsChain:destroy()
local chain=ChainDefinition.new(definition,{exclusive=true},function(joints,localPoint,options)
 return ChainAdapter.new(joints,localPoint,options,Solver.new(Limits))
end)
local result=chain:solve(Vector3.new(1,1,0))
assert(result.converged and result.error<=0.02,'authored tolerance should govern convergence')
assert(#chain:destroy()==0)
j2:SetAttribute('EditRigIK_LowerDegrees',-45)
ChainBuilder.new(Config).refreshLimits(definition)
local refreshedLimits
local refreshed=ChainDefinition.new(definition,{exclusive=true},function(_,_,options)
 refreshedLimits=options.limits
 return {solve=function() end,destroy=function() return {} end}
end)
assert(math.abs(refreshedLimits[2].lower-math.rad(-45))<1e-8,'reopened chain must use refreshed joint limits')
refreshed:destroy()
local chain2=ChainDefinition.new(definition,{exclusive=true},function(joints,localPoint,options)
 return ChainAdapter.new(joints,localPoint,options,Solver.new(Limits))
end)
endpoint.Position=Vector3.new(2,0,0)
assert(not pcall(function() chain2:solve(Vector3.new(1,1,0)) end),'endpoint changes require rebuilding the chain')
assert(#chain2:destroy()==0)
local root=Instance.new('Bone'); root.Name='Root'; root.Parent=a
local child=Instance.new('Bone'); child.CFrame=CFrame.new(1,0,0); child.Parent=root
local boneTip=Instance.new('Attachment'); boneTip.Position=Vector3.new(1,0,0); boneTip.Parent=child
for _,j in ipairs({root,child}) do
 j:SetAttribute('EditRigIK_SchemaVersion',1); j:SetAttribute('EditRigIK_Kind','Hinge'); j:SetAttribute('EditRigIK_Axis','Z')
 j:SetAttribute('EditRigIK_LowerDegrees',-180); j:SetAttribute('EditRigIK_UpperDegrees',180); j:SetAttribute('EditRigIK_SwingDegrees',90)
end
local boneDefinition=ChainBuilder.new(Config).create(model,root,child,boneTip,'Tail'); boneDefinition.Parent=folder
assert(boneDefinition:GetAttribute('MaxStepDegrees')==180,'default correction angle preserves existing behavior')
boneDefinition:SetAttribute('MaxStepDegrees',nil) -- definitions saved before this option
local boneOptions=ChainDefinition.new(boneDefinition,{exclusive=true},function()
 return {solve=function(_,_,options) captured=options; return options end,destroy=function() return {} end}
end)
boneOptions:solve(Vector3.zero,{iterations=9})
assert(captured.iterations==9 and captured.tolerance==0.01 and captured.maxStep==math.pi,'Bone chain must retain saved settings')
boneOptions:destroy()
boneDefinition:SetAttribute('MaxStepDegrees',0)
assert(not pcall(function() ChainDefinition.new(boneDefinition,{exclusive=true},function() end) end),'invalid saved correction angle must fail')
boneDefinition:SetAttribute('MaxStepDegrees',180)
local boneChain=ChainDefinition.new(boneDefinition,{exclusive=true},function(joints,localPoint,options)
 return ChainAdapter.new(joints,localPoint,options,Solver.new(Limits))
end)
assert(boneChain:solve(Vector3.new(1,1,0)).converged,'authored Bone chain must converge')
assert(#boneChain:destroy()==0)
model:Destroy()
return 'Configured chain authoring to IK solve passed'
