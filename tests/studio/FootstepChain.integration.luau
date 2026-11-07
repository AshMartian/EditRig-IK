local model=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model
local c=Instance.new('Part'); c.Parent=model
local j1=Instance.new('Motor6D'); j1.Part0=a; j1.Part1=b; j1.Parent=a
local j2=Instance.new('Motor6D'); j2.Part0=b; j2.Part1=c; j2.C0=CFrame.new(1,0,0); j2.Parent=b
local tip=Instance.new('Attachment'); tip.Position=Vector3.xAxis; tip.Parent=c
for _,joint in ipairs({j1,j2}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',90)
end
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local def=ChainBuilder.new(Config).create(model,j1,j2,tip,'Leg'); def.Parent=folder
local components={trajectory=StepTrajectory,behavior=FootstepBehavior,createChain=function(options)
 return ChainDefinition.new(def,options,function(joints,endpoint,chainOptions) return ChainAdapter.new(joints,endpoint,chainOptions,Solver.new(Limits)) end)
end}
local controller=FootstepChain.new({exclusive=true,start=Vector3.new(1,1,0),up=Vector3.yAxis,height=.1,duration=1},components)
controller:requestStep(Vector3.new(1.1,.9,0))
local result=controller:step(.5)
assert(result.moving and result.solve.converged and (result.target-Vector3.new(1.05,1.05,0)).Magnitude<1e-4)
result=controller:step(.5)
assert(not result.moving and result.solve.converged and (result.target-Vector3.new(1.1,.9,0)).Magnitude<1e-4)
assert(#controller:destroy()==0)
assert(not pcall(function() controller:step(.1) end))
def:SetAttribute('MaxSpeedDegrees',1)
local limited=FootstepChain.new({exclusive=true,start=Vector3.new(1,1,0),up=Vector3.yAxis,height=.1,duration=1},components)
local limitedResult=limited:step(.1)
assert(limitedResult.solve.motionLimited,'footstep must forward dt to the authored chain speed cap')
local actualEndpoint=(a.CFrame*j1.C0*j1.Transform*j1.C1:Inverse()*j2.C0*j2.Transform*j2.C1:Inverse()):PointToWorldSpace(tip.Position)
assert((limitedResult.solve.endpointWorld-actualEndpoint).Magnitude<1e-5,'multi-joint diagnostics must match the applied pose')
limited:destroy()
assert(not pcall(function() FootstepChain.new({exclusive=true,start=Vector3.zero,up=Vector3.yAxis,height=.1,duration=0},components) end))
local root=Instance.new('Bone'); root.Parent=a
local child=Instance.new('Bone'); child.CFrame=CFrame.new(1,0,0); child.Parent=root
local boneTip=Instance.new('Attachment'); boneTip.Position=Vector3.xAxis; boneTip.Parent=child
for _,joint in ipairs({root,child}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',90)
end
local boneDef=ChainBuilder.new(Config).create(model,root,child,boneTip,'BoneLeg'); boneDef.Parent=folder
components.createChain=function(options)
 return ChainDefinition.new(boneDef,options,function(joints,endpoint,chainOptions) return ChainAdapter.new(joints,endpoint,chainOptions,Solver.new(Limits)) end)
end
local boneController=FootstepChain.new({exclusive=true,start=Vector3.new(1,1,0),up=Vector3.yAxis,height=.1,duration=1},components)
boneController:requestStep(Vector3.new(1.1,.9,0))
assert(boneController:step(.5).solve.converged and boneController:step(.5).solve.converged,'Bone footstep chain must solve')
assert(#boneController:destroy()==0)
model:Destroy()
return 'Footstep chain controller drives authored Motor6D and Bone chains'
