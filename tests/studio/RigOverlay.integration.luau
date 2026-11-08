-- RigOverlay is injected by the Studio test harness.
assert(RigOverlay, 'RigOverlay must be available')
assert(ChainInference, 'ChainInference must be available')
local rig=Instance.new('Model'); rig.Name='OverlayFixture'; rig.Parent=workspace
local a=Instance.new('Part'); a.Anchored=true; a.CFrame=CFrame.new(3,4,5); a.Parent=rig
local b=Instance.new('Part'); b.Anchored=true; b.Parent=rig
local c=Instance.new('Part'); c.Anchored=true; c.Parent=rig
local first=Instance.new('Motor6D'); first.Part0=a; first.Part1=b; first.C0=CFrame.new(0,2,0); first.Parent=a
local second=Instance.new('Motor6D'); second.Part0=b; second.Part1=c; second.C0=CFrame.new(0,1,0); second.Parent=b
local bone=Instance.new('Bone'); bone.CFrame=CFrame.new(1,0,0); bone.Parent=a
local child=Instance.new('Bone'); child.CFrame=CFrame.new(0,1,0); child.Parent=bone
local boneTip=Instance.new('Attachment'); boneTip.Parent=child
local tip=Instance.new('Attachment'); tip.Parent=c
local midTip=Instance.new('Attachment'); midTip.Parent=b
local holder=Instance.new('Folder'); holder.Parent=game:GetService('CoreGui')
local overlay=RigOverlay.new(rig,holder,function() end,ChainInference)
assert(overlay:count()==4,'all Motor6D and Bone joints should get markers')
overlay:update()
local markers,links=0,0
for _,x in ipairs(holder:GetChildren()) do
 if x:IsA('SphereHandleAdornment') then markers+=1; assert(x.Adornee,'marker must be attached to a part') end
 if x:IsA('WireframeHandleAdornment') and x.Adornee then links+=1 end
end
assert(markers==4 and links==2,'each child joint should link to its parent joint')
local outline=holder:FindFirstChild('EditRigIKSelectedOutline')
assert(outline and not outline.Adornee,'selection outline starts hidden')
overlay:update(first); assert(outline.Adornee==a,'selected joint receives an outline')
assert(overlay:chainState().ok and #overlay:chainState().joints==2,'an unambiguous chain is reported')
local beforeEndpointRename=overlay:chainState()
tip.Name='RenamedEndpoint'; task.wait(); overlay:update(first)
assert(overlay:chainState()~=beforeEndpointRename and overlay:chainState().endpoint.Name=='RenamedEndpoint','endpoint rename refreshes the chain view')
local bright,dim=0,0
for _,x in ipairs(holder:GetChildren()) do
 if x:IsA('SphereHandleAdornment') then if x.Transparency<.2 then bright+=1 else dim+=1 end end
end
assert(bright==2 and dim==2,'unrelated Bone joints are dimmed while the selected Motor6D chain is emphasized')
local branchPart=Instance.new('Part'); branchPart.Parent=rig
local branch=Instance.new('Motor6D'); branch.Part0=b; branch.Part1=branchPart; branch.Parent=rig
task.wait(); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='ambiguous','branching cannot select a guessed chain')
for _,x in ipairs(holder:GetChildren()) do if x:IsA('SphereHandleAdornment') then assert(x.Transparency<.2,'ambiguous paths remain neutral') end end
overlay:setChainOptions(first,tip,second); overlay:update(first)
assert(overlay:chainState().ok and #overlay:chainState().joints==2 and overlay:chainState().endpoint==tip,'explicit root and endpoint resolve a branch')
local sameOptions=overlay:chainState()
overlay:setChainOptions(first,tip,second); overlay:update(first)
assert(overlay:chainState()==sameOptions,'unchanged preferences do not rerun inference')
overlay:setChainOptions(first,tip,first); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='explicit_end_mismatch','an explicit end joint cannot silently resolve to another joint')
overlay:setChainOptions(first,nil,second); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='missing_explicit_endpoint','an explicit end joint cannot silently infer an endpoint')
local staleJoint=Instance.new('Motor6D'); staleJoint.Parent=rig; staleJoint:Destroy()
overlay:setChainOptions(first,tip,staleJoint); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='invalid_end_joint','a stale explicit end joint is rejected')
local stale=Instance.new('Attachment'); stale.Parent=c; stale:Destroy()
overlay:setChainOptions(first,stale); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='invalid_endpoint','invalid explicit endpoint must not fall back to a guessed chain')
overlay:setChainOptions(branch,tip); overlay:update(first)
assert(not overlay:chainState().ok,'disconnected explicit root must not fall back to a guessed chain')
overlay:setChainOptions(nil,nil); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='ambiguous','clearing preferences restores honest ambiguity')
branch:Destroy(); branchPart:Destroy(); task.wait(); overlay:update(first)
assert(overlay:chainState().ok,'a resolved branch is inferred again')
tip.Parent=nil; task.wait(); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='missing_endpoint','missing endpoints disable chain emphasis')
tip.Parent=c; task.wait()
second.Enabled=false; task.wait(); overlay:update(first)
assert(overlay:chainState().ok and #overlay:chainState().joints==1,'disabled Motor6D changes the inferred path')
second.Enabled=true; task.wait(); overlay:update(first)
assert(overlay:chainState().ok and #overlay:chainState().joints==2,'re-enabled Motor6D restores inference')
second.Part1=nil; task.wait(); overlay:update(first)
assert(not overlay:chainState().ok,'a broken Motor6D cannot retain a stale inferred path')
second.Part1=c; task.wait()
second.Part0=a; task.wait(); overlay:update(first)
assert(overlay:chainState().ok and #overlay:chainState().joints==1,'Part0 changes invalidate the inferred path')
second.Part0=b; task.wait(); overlay:update(first)
assert(overlay:chainState().ok and #overlay:chainState().joints==2,'restored Part0 reconnects the path')
overlay:update(child)
assert(overlay:chainState().ok and #overlay:chainState().joints==2,'Bone parent chain is inferred and emphasized')
local boneBranch=Instance.new('Bone'); boneBranch.Parent=bone
task.wait(); overlay:update(bone)
assert(not overlay:chainState().ok and overlay:chainState().reason=='ambiguous','a branching Bone hierarchy does not choose a chain')
boneBranch:Destroy(); task.wait()
local added=Instance.new('Bone'); added.Parent=a
task.wait(); overlay:update(added)
assert(overlay:chainState() and overlay:chainState().reason=='overlay_stale','newly added selected joints must request overlay rebuild')
added:Destroy(); task.wait(); overlay:update(first)
local beforeRename=overlay:chainState()
first.Name='RenamedRoot'; task.wait(); overlay:update(first)
assert(overlay:chainState()~=beforeRename and overlay:chainState().joints[1].Name=='RenamedRoot','joint rename refreshes chain labels')
overlay:update(child); beforeRename=overlay:chainState()
child.Name='RenamedBone'; task.wait(); overlay:update(child)
assert(overlay:chainState()~=beforeRename and overlay:chainState().joints[2].Name=='RenamedBone','Bone rename refreshes chain labels')
child.Parent=a; task.wait(); overlay:update(child)
assert(overlay:chainState().ok and #overlay:chainState().joints==1,'Bone reparenting within the rig invalidates the old chain')
child.Parent=bone; task.wait(); overlay:update(child)
assert(overlay:chainState().ok and #overlay:chainState().joints==2,'Bone reparenting back restores the chain')
local extra=Instance.new('Part'); extra.Name='ExtraBoneParent'; extra.Anchored=true
extra.CanCollide=false; extra.CanTouch=false; extra.CanQuery=false; extra.Parent=rig
for _=1,297 do local node=Instance.new('Bone'); node.Parent=extra end
task.wait(); overlay:update(first)
assert(not overlay:chainState().ok and overlay:chainState().reason=='too_complex','large edited rigs fail safely instead of inferring an unbounded graph')
extra:Destroy(); task.wait(); overlay:update(first)
assert(overlay:chainState().ok,'graph inference resumes after excess joints are removed')
overlay:update(second); assert(outline.Adornee==b,'outline follows selection to the other joint')
overlay:update(nil); assert(not outline.Adornee,'outline clears when selection is removed')
first.Part0=nil; overlay:update()
local hidden=0; for _,x in ipairs(holder:GetChildren()) do if x:IsA('SphereHandleAdornment') and not x.Adornee then hidden+=1 end end
assert(hidden==1,'invalid joint marker must be hidden')
overlay:destroy(); assert(#holder:GetChildren()==0,'destroy must remove every overlay object')
holder:Destroy(); rig:Destroy()
return 'Rig overlay Motor6D and Bone markers, links, invalidation and cleanup passed'
