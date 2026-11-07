-- RigOverlay is injected by the Studio test harness.
assert(RigOverlay, 'RigOverlay must be available')
local rig=Instance.new('Model'); rig.Name='OverlayFixture'; rig.Parent=workspace
local a=Instance.new('Part'); a.Anchored=true; a.CFrame=CFrame.new(3,4,5); a.Parent=rig
local b=Instance.new('Part'); b.Anchored=true; b.Parent=rig
local c=Instance.new('Part'); c.Anchored=true; c.Parent=rig
local first=Instance.new('Motor6D'); first.Part0=a; first.Part1=b; first.C0=CFrame.new(0,2,0); first.Parent=a
local second=Instance.new('Motor6D'); second.Part0=b; second.Part1=c; second.C0=CFrame.new(0,1,0); second.Parent=b
local bone=Instance.new('Bone'); bone.CFrame=CFrame.new(1,0,0); bone.Parent=a
local child=Instance.new('Bone'); child.CFrame=CFrame.new(0,1,0); child.Parent=bone
local holder=Instance.new('Folder'); holder.Parent=game:GetService('CoreGui')
local overlay=RigOverlay.new(rig,holder,function() end)
assert(overlay:count()==4,'all Motor6D and Bone joints should get markers')
overlay:update()
local markers,links=0,0
for _,x in ipairs(holder:GetChildren()) do
 if x:IsA('SphereHandleAdornment') then markers+=1; assert(x.Adornee,'marker must be attached to a part') end
 if x:IsA('WireframeHandleAdornment') and x.Adornee then links+=1 end
end
assert(markers==4 and links==2,'each child joint should link to its parent joint')
first.Part0=nil; overlay:update()
local hidden=0; for _,x in ipairs(holder:GetChildren()) do if x:IsA('SphereHandleAdornment') and not x.Adornee then hidden+=1 end end
assert(hidden==1,'invalid joint marker must be hidden')
overlay:destroy(); assert(#holder:GetChildren()==0,'destroy must remove every overlay object')
holder:Destroy(); rig:Destroy()
return 'Rig overlay Motor6D and Bone markers, links, invalidation and cleanup passed'
