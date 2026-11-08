assert(SurfaceContactGizmo, 'surface contact gizmo required')
local world=Instance.new('Folder')
local gizmo=SurfaceContactGizmo.new(world)
assert(gizmo:isValid(), 'new gizmo must be valid')
local folder=world:FindFirstChild('EditRigIKSurfaceContact')
assert(folder and not folder.Archivable, 'gizmo must own a temporary container')
local marker=folder:FindFirstChild('Contact')
local normal=folder:FindFirstChild('Normal')
local tip=folder:FindFirstChild('NormalTip')
assert(marker and normal and tip, 'contact, normal and tip must exist')
for _,part in ipairs({marker,normal,tip}) do
 assert(part:IsA('BasePart') and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.Archivable, 'guides must be temporary and noninteractive')
 assert(part.Transparency==1, 'new guides must start hidden')
end
local point=Vector3.new(2,3,-4)
local direction=Vector3.new(1,2,3).Unit
gizmo:update({status='contact',position=point,normal=direction*2})
assert(marker.Transparency<1 and normal.Transparency<1 and tip.Transparency<1,'contact is shown')
assert((marker.Position-point).Magnitude<1e-5, 'marker must sit at contact')
assert((normal.CFrame.LookVector-direction).Magnitude<1e-5, 'normal line points along the surface normal')
assert((tip.Position-point-direction*normal.Size.Z).Magnitude<1e-5, 'normal tip marks the outward end')
for _,sample in ipairs({{status='no contact'},{status='excluded slope'},{status='invalid contact'}, {status='contact',position=point,normal=Vector3.zero}, {status='contact',position=Vector3.new(0/0,0,0),normal=direction}}) do
 gizmo:update(sample)
 assert(marker.Transparency==1 and normal.Transparency==1 and tip.Transparency==1, 'missing, excluded or invalid contact hides old guides')
end
gizmo:update({status='contact',position=point,normal=direction})
gizmo:update(nil)
assert(marker.Transparency==1 and normal.Transparency==1 and tip.Transparency==1, 'nil clears contact')
gizmo:destroy(); gizmo:destroy()
assert(#world:GetChildren()==0 and not gizmo:isValid(), 'destroy is idempotent and removes temporary objects')
assert(not pcall(function() gizmo:update(nil) end), 'destroyed gizmos reject updates')
for _,name in ipairs({'Contact','Normal','NormalTip'}) do
 local probe=SurfaceContactGizmo.new(world)
 local child=world:FindFirstChild('EditRigIKSurfaceContact'):FindFirstChild(name)
 child.Parent=nil
 assert(not probe:isValid(), 'missing '..name..' invalidates gizmo')
 assert(not pcall(function() probe:update({status='contact',position=point,normal=direction}) end), 'invalid gizmos reject updates')
 probe:destroy()
 assert(#world:GetChildren()==0 and child.Parent==nil, 'cleanup removes remaining objects')
end
world:Destroy()
return 'Surface contact gizmo positioning, hiding and cleanup passed'
