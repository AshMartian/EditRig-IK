local model=Instance.new('Model'); model.Name='GhostFixture'
local a=Instance.new('Part'); a.Name='Base'; a.Anchored=true; a.Parent=model
local b=Instance.new('Part'); b.Name='Tip'; b.CFrame=CFrame.new(1,0,0); b.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Root'; motor.Part0=a; motor.Part1=b; motor.Parent=a
local endpoint=Instance.new('Attachment'); endpoint.CFrame=CFrame.new(1,0,0)*CFrame.Angles(.1,.2,.3); endpoint.Parent=b
motor:SetAttribute('EditRigIK_SchemaVersion',1); motor:SetAttribute('EditRigIK_Kind','Ball'); motor:SetAttribute('EditRigIK_Axis','Z')
motor:SetAttribute('EditRigIK_LowerDegrees',-180); motor:SetAttribute('EditRigIK_UpperDegrees',180); motor:SetAttribute('EditRigIK_SwingDegrees',180)
local branch=Instance.new('Part'); branch.Name='Branch'; branch.CFrame=b.CFrame*CFrame.new(0,1,0); branch.Parent=model
local weld=Instance.new('WeldConstraint'); weld.Part0=b; weld.Part1=branch; weld.Parent=b
local scriptObject=Instance.new('Script'); scriptObject.Parent=model
local sound=Instance.new('Sound'); sound.Parent=b
local click=Instance.new('ClickDetector'); click.Parent=b
local prompt=Instance.new('ProximityPrompt'); prompt.Parent=b
local drag=Instance.new('DragDetector'); drag.Parent=b
local light=Instance.new('PointLight'); light.Parent=b
local billboard=Instance.new('BillboardGui'); billboard.Parent=b
local explosion=Instance.new('Explosion'); explosion.Parent=model
local outside=Instance.new('Part')
local externalRef=Instance.new('ObjectValue'); externalRef.Name='ExternalReference'; externalRef.Value=outside; externalRef.Parent=model
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local definition=ChainBuilder.new(Config).create(model,motor,motor,endpoint,'Arm'); definition.Parent=folder
local parent=Instance.new('Folder')
local engine=Solver.new(Limits)
local components={createChain=function(def)
 return ChainDefinition.new(def,{exclusive=true},function(joints,point,opts) return ChainAdapter.new(joints,point,opts,engine) end)
end}
local session=WorldGhostSession.new(definition,parent,components)
assert(session:isValid(),'new ghost session must be valid')
local ghost=parent:FindFirstChild('GhostFixture'); assert(ghost and ghost~=model,'ghost must be parented separately')
assert(not ghost.Archivable,'temporary ghost must not be archivable')
assert(not ghost:FindFirstChildOfClass('Script') and not ghost.Tip:FindFirstChildOfClass('Sound'),'active content must be removed')
assert(not ghost:FindFirstChildOfClass('Explosion'),'explosions must be removed before the ghost is parented')
for _,class in ipairs({'ClickDetector','ProximityPrompt','DragDetector','PointLight','BillboardGui'}) do
 assert(not ghost.Tip:FindFirstChildOfClass(class),class..' must be removed')
end
assert(ghost.ExternalReference.Value==nil,'external ObjectValue references must be cleared')
assert(ghost.Tip.Anchored and not ghost.Tip.CanCollide and not ghost.Tip.CanTouch and not ghost.Tip.CanQuery and ghost.Tip.Transparency>=.5,'ghost parts must be inert and translucent')
local cloneDef=ghost.EditRigIKChains.Arm
assert(cloneDef.Endpoint.Value:IsDescendantOf(ghost) and cloneDef.Joints.Joint001.Value:IsDescendantOf(ghost),'chain references must remain inside clone')
assert(ghost.Tip.CFrame:FuzzyEq(b.CFrame,1e-5),'initial ghost pose must match source even when detached motor FK differs')
local start=session:startTarget()
assert((start-endpoint.WorldPosition).Magnitude<1e-5,'starting target must match the captured endpoint')
assert(session:startOrientation():FuzzyEq(endpoint.WorldCFrame.Rotation,1e-5),'starting orientation must capture the endpoint attachment rotation')
local result=session:solveTarget(start+Vector3.new(-1,1,0))
assert(typeof(result.endpointWorld)=='Vector3' and type(result.error)=='number' and type(result.converged)=='boolean','solve must return endpoint diagnostics')
assert(ghost.Branch.CFrame:FuzzyEq(ghost.Tip.CFrame*CFrame.new(0,1,0),1e-4),'welded branches must follow')
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5) and b.CFrame:FuzzyEq(CFrame.new(1,0,0),1e-5),'source pose must remain unchanged')
session:reset(); assert(ghost.Tip.CFrame:FuzzyEq(b.CFrame,1e-5),'reset must restore starting pose')
local motorTarget=CFrame.Angles(0,0,.3)*endpoint.CFrame
local posed=session:solveTarget(motorTarget.Position,{targetOrientation=motorTarget.Rotation,orientationTolerance=.02})
assert(type(posed.orientationError)=='number' and type(posed.orientationConverged)=='boolean','Motor6D preview must report orientation diagnostics')
assert(posed.orientationError<.05,'Motor6D preview should approach a reachable orientation')
assert(posed.endpointOrientationWorld:FuzzyEq(ghost.Tip.CFrame.Rotation*endpoint.CFrame.Rotation,1e-4),'Motor6D reported orientation must match clone endpoint')
assert(motor.Transform:FuzzyEq(CFrame.identity,1e-5),'orientation preview must not move the source Motor6D')
assert(not pcall(function() session:solveTarget(start,{targetOrientation=CFrame.new(math.huge,0,0)}) end),'nonfinite orientation must be rejected')
assert(session:isValid(),'invalid options must not destroy the session')
assert(not pcall(function() session:solveTarget(start,{orientationTolerance=-1}) end),'invalid tolerance must be rejected')
assert(session:isValid(),'invalid tolerance must not destroy the session')
assert(not pcall(function() session:solveTarget(Vector3.new(0/0,0,0)) end),'nonfinite target must be rejected')
session:destroy(); session:destroy(); assert(#parent:GetChildren()==0,'destroy must remove ghost')
local removed=WorldGhostSession.new(definition,parent,components)
local removedClone=parent:FindFirstChild('GhostFixture'); removedClone.Parent=nil
assert(not removed:isValid(),'removing or reparenting the ghost invalidates the session')
assert(not pcall(function() removed:solveTarget(Vector3.zero) end),'invalid ghost must not solve')
removed:destroy(); assert(#parent:GetChildren()==0,'invalid ghost cleanup removes the session')
local missingEndpoint=WorldGhostSession.new(definition,parent,components)
local endpointClone=parent.GhostFixture.EditRigIKChains.Arm.Endpoint.Value
endpointClone.Parent=nil
assert(not missingEndpoint:isValid(),'removing the ghost endpoint invalidates the session')
missingEndpoint:destroy(); endpointClone:Destroy()
assert(not pcall(function() WorldGhostSession.new(definition,parent,{createChain=function() error('construction failed') end}) end))
assert(#parent:GetChildren()==0,'failed construction must clean up')
local failingReset=WorldGhostSession.new(definition,parent,{createChain=function()
 return {solve=function() error('not used') end,destroy=function() error('destroy failed') end}
end})
assert(not pcall(function() failingReset:reset() end),'reset must report chain destruction failure')
assert(#parent:GetChildren()==0,'failed reset must remove ghost even if chain destruction throws')
failingReset:destroy()
local root=Instance.new('Bone'); root.Name='BoneRoot'; root.Parent=a
local child=Instance.new('Bone'); child.Name='BoneEnd'; child.CFrame=CFrame.new(1,0,0); child.Parent=root
local boneTip=Instance.new('Attachment'); boneTip.CFrame=CFrame.new(1,0,0)*CFrame.Angles(-.1,.2,-.3); boneTip.Parent=child
for _,joint in ipairs({root,child}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Ball'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',180)
end
local bones=ChainBuilder.new(Config).create(model,root,child,boneTip,'Tail'); bones.Parent=folder
local boneSession=WorldGhostSession.new(bones,parent,components)
local boneStart=boneSession:startTarget()
assert(boneSession:startOrientation():FuzzyEq((child.TransformedWorldCFrame*boneTip.CFrame).Rotation,1e-5),'Bone starting orientation must include the attachment rotation')
local boneTarget=root.CFrame*CFrame.Angles(0,0,.3)*child.CFrame*boneTip.CFrame
local bonePose=boneSession:solveTarget(boneTarget.Position,{targetOrientation=boneTarget.Rotation,orientationTolerance=.02})
assert(type(bonePose.orientationError)=='number' and bonePose.orientationError<.05,'Bone preview should approach the requested orientation')
local cloneBone=parent.GhostFixture.Base.BoneRoot.BoneEnd
assert(bonePose.endpointOrientationWorld:FuzzyEq((cloneBone.TransformedWorldCFrame*boneTip.CFrame).Rotation,1e-4),'Bone diagnostic must match the cloned attachment orientation')
assert(root.Transform:FuzzyEq(CFrame.identity,1e-5) and child.Transform:FuzzyEq(CFrame.identity,1e-5),'orientation preview must not move source Bones')
boneSession:reset()
local boneResult=boneSession:solveTarget(boneStart+Vector3.new(-1,1,0))
assert(typeof(boneResult.endpointWorld)=='Vector3' and boneResult.error<.05,'Bone ghost must solve')
assert(root.Transform:FuzzyEq(CFrame.identity,1e-5) and child.Transform:FuzzyEq(CFrame.identity,1e-5),'source Bones must not move')
boneSession:reset()
local ghostBone=parent.GhostFixture.Base.BoneRoot
assert(ghostBone.Transform:FuzzyEq(CFrame.identity,1e-5) and ghostBone.BoneEnd.Transform:FuzzyEq(CFrame.identity,1e-5),'Bone reset must restore transforms')
boneSession:destroy()
model:Destroy(); outside:Destroy(); parent:Destroy()
return 'World ghost is isolated and disposable'
