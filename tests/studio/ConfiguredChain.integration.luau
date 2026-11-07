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
local definition=ChainBuilder.new(Config).create(model,j1,j2,endpoint,'Leg'); definition.Parent=folder
local chain=ChainDefinition.new(definition,{exclusive=true},function(joints,localPoint,options)
 return ChainAdapter.new(joints,localPoint,options,Solver.new(Limits))
end)
local result=chain:solve(Vector3.new(1,1,0))
assert(result.converged and result.error<0.01)
endpoint.Position=Vector3.new(2,0,0)
assert(not pcall(function() chain:solve(Vector3.new(1,1,0)) end),'endpoint changes require rebuilding the chain')
assert(#chain:destroy()==0)
local root=Instance.new('Bone'); root.Name='Root'; root.Parent=a
local child=Instance.new('Bone'); child.CFrame=CFrame.new(1,0,0); child.Parent=root
local boneTip=Instance.new('Attachment'); boneTip.Position=Vector3.new(1,0,0); boneTip.Parent=child
for _,j in ipairs({root,child}) do
 j:SetAttribute('EditRigIK_SchemaVersion',1); j:SetAttribute('EditRigIK_Kind','Hinge'); j:SetAttribute('EditRigIK_Axis','Z')
 j:SetAttribute('EditRigIK_LowerDegrees',-180); j:SetAttribute('EditRigIK_UpperDegrees',180); j:SetAttribute('EditRigIK_SwingDegrees',90)
end
local boneDefinition=ChainBuilder.new(Config).create(model,root,child,boneTip,'Tail'); boneDefinition.Parent=folder
local boneChain=ChainDefinition.new(boneDefinition,{exclusive=true},function(joints,localPoint,options)
 return ChainAdapter.new(joints,localPoint,options,Solver.new(Limits))
end)
assert(boneChain:solve(Vector3.new(1,1,0)).converged,'authored Bone chain must converge')
assert(#boneChain:destroy()==0)
model:Destroy()
return 'Configured chain authoring to IK solve passed'
