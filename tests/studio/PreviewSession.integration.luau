local model=Instance.new('Model'); model.Name='Rig'
local a=Instance.new('Part'); a.Name='Base'; a.Anchored=true; a.Parent=model
local b=Instance.new('Part'); b.Name='Mid'; b.CFrame=CFrame.new(1,0,0); b.Parent=model
local c=Instance.new('Part'); c.Name='Tip'; c.CFrame=CFrame.new(2,0,0); c.Parent=model
local j1=Instance.new('Motor6D'); j1.Name='Root'; j1.Part0=a; j1.Part1=b; j1.Parent=a
local j2=Instance.new('Motor6D'); j2.Name='Elbow'; j2.Part0=b; j2.Part1=c; j2.C0=CFrame.new(1,0,0); j2.Parent=b
local branch=Instance.new('Part'); branch.Name='Branch'; branch.CFrame=c.CFrame*CFrame.new(0,1,0); branch.Parent=model
local branchJoint=Instance.new('Motor6D'); branchJoint.Name='BranchJoint'; branchJoint.Part0=c; branchJoint.Part1=branch; branchJoint.C0=CFrame.new(0,1,0); branchJoint.Parent=c
local accessory=Instance.new('Part'); accessory.Name='Accessory'; accessory.CFrame=branch.CFrame*CFrame.new(0,0,.4); accessory.Parent=model
local weld=Instance.new('WeldConstraint'); weld.Part0=branch; weld.Part1=accessory; weld.Parent=branch
local loose=Instance.new('Part'); loose.Name='Loose'; loose.CFrame=CFrame.new(5,5,5); loose.Parent=model
local disabled=Instance.new('WeldConstraint'); disabled.Part0=c; disabled.Part1=loose; disabled.Enabled=false; disabled.Parent=c
local tip=Instance.new('Attachment'); tip.Position=Vector3.xAxis; tip.Parent=c
for _,joint in ipairs({j1,j2}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Ball'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',180)
end
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local definition=ChainBuilder.new(Config).create(model,j1,j2,tip,'Leg'); definition.Parent=folder
local view=Instance.new('ViewportFrame')
local engine=Solver.new(Limits)
local session=PreviewSession.new(definition,view,{createChain=function(def)
 return ChainDefinition.new(def,{exclusive=true},function(joints,point,opts) return ChainAdapter.new(joints,point,opts,engine) end)
end})
local result=session:solveOffset(Vector3.new(-1,1,0))
assert(result.converged and result.error<.02)
local previewWorld=view:FindFirstChildOfClass('WorldModel')
local targetMarker=previewWorld:FindFirstChild('EditRigIKTargetMarker')
local endMarker=previewWorld:FindFirstChild('EditRigIKEndpointMarker')
assert(targetMarker and endMarker,'preview must create target and endpoint markers')
assert((targetMarker.Position-Vector3.new(1,1,0)).Magnitude<1e-4,'target marker must show requested position')
assert((endMarker.Position-result.endpointWorld).Magnitude<1e-4,'endpoint marker must show actual solve result')
local cameraBefore=view.CurrentCamera.CFrame
local unreachable=session:solveOffset(Vector3.new(10,0,0))
assert(not unreachable.converged and (targetMarker.Position-endMarker.Position).Magnitude>5,'unreachable target must show a separated endpoint')
assert(not view.CurrentCamera.CFrame:FuzzyEq(cameraBefore,1e-4),'camera should reframe distant targets')
assert(session:solveOffset(Vector3.new(-.9,1,0)).converged,'preview must accept repeated solves')
local previewRig=view:FindFirstChildOfClass('WorldModel'):FindFirstChild('Rig')
local previewTip=previewRig:FindFirstChild('Tip'); local previewBranch=previewRig:FindFirstChild('Branch'); local previewAccessory=previewRig:FindFirstChild('Accessory')
assert(previewBranch.CFrame:FuzzyEq(previewTip.CFrame*CFrame.new(0,1,0),1e-5),'branch Motor6D must follow the preview chain')
assert(previewAccessory.CFrame:FuzzyEq(previewBranch.CFrame*CFrame.new(0,0,.4),1e-5),'welded accessory must follow the preview branch')
assert(previewRig:FindFirstChild('Loose').CFrame:FuzzyEq(CFrame.new(5,5,5),1e-5),'disabled constraints must not move parts')
assert(j1.Transform:FuzzyEq(CFrame.identity,1e-5) and j2.Transform:FuzzyEq(CFrame.identity,1e-5),'source joints must never move')
assert(b.CFrame:FuzzyEq(CFrame.new(1,0,0),1e-5) and c.CFrame:FuzzyEq(CFrame.new(2,0,0),1e-5),'source parts must never move')
assert(view:FindFirstChildOfClass('WorldModel') and view.CurrentCamera,'preview must have its own world and camera')
session:destroy()
assert(#view:GetChildren()==0 and view.CurrentCamera==nil,'closing preview must remove all generated objects')
local root=Instance.new('Bone'); root.Name='BoneRoot'; root.Parent=a
local child=Instance.new('Bone'); child.Name='BoneEnd'; child.CFrame=CFrame.new(1,0,0); child.Parent=root
local boneTip=Instance.new('Attachment'); boneTip.Position=Vector3.xAxis; boneTip.Parent=child
for _,joint in ipairs({root,child}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Ball'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',180)
end
local bones=ChainBuilder.new(Config).create(model,root,child,boneTip,'Tail'); bones.Parent=folder
local boneSession=PreviewSession.new(bones,view,{createChain=function(def)
 return ChainDefinition.new(def,{exclusive=true},function(joints,point,opts) return ChainAdapter.new(joints,point,opts,engine) end)
end})
assert(boneSession:solveOffset(Vector3.new(-1,1,0)).converged,'Bone preview must solve')
assert(root.Transform:FuzzyEq(CFrame.identity,1e-5) and child.Transform:FuzzyEq(CFrame.identity,1e-5),'Bone source must remain unchanged')
boneSession:destroy()
assert(not pcall(function() PreviewSession.new(definition,view,{createChain=function() error('failed construction') end}) end))
assert(#view:GetChildren()==0 and view.CurrentCamera==nil,'failed preview must clean up')
model:Destroy(); view:Destroy()
return 'Clone pose preview isolates Motor6D and Bone source rigs'
