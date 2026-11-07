local rig=Instance.new('Model')
local root=Instance.new('Part'); root.Parent=rig; rig.PrimaryPart=root
local targets=Instance.new('Folder'); targets.Name='IkTargets'; targets.Parent=rig
local rays=Instance.new('Folder'); rays.Name='RaycastParts'; rays.Parent=rig
for _,side in ipairs({'Left','Right'}) do
 local t=Instance.new('Part'); t.Name=side..' Target'; t.Anchored=true; t.Parent=targets
 local ray=Instance.new('Part'); ray.Name=side..' Raycast Part'; ray.Parent=rays
end
local template=Instance.new('Script'); template.Disabled=true
local module=Instance.new('ModuleScript'); module.Name='DinoSmoothGait'; module.Parent=template
local copy=GaitExampleInstaller.prepare(rig,template)
assert(copy:IsA('Script') and copy.Disabled and copy.Parent==nil and copy.Name=='EditRigIKSmoothGaitExample','prepared script must be detached and disabled')
assert(copy:FindFirstChild('DinoSmoothGait') and not rig:FindFirstChild(copy.Name),'preparing must preserve the source rig')
copy.Parent=rig
assert(not pcall(function() GaitExampleInstaller.prepare(rig,template) end),'must not overwrite existing example')
assert(rig:FindFirstChild(copy.Name)==copy,'existing example must remain intact')
copy:Destroy(); targets['Left Target'].Anchored=false
assert(not pcall(function() GaitExampleInstaller.prepare(rig,template) end),'unanchored targets must be rejected')
assert(not rig:FindFirstChild('EditRigIKSmoothGaitExample'),'validation must not insert anything')
rig:Destroy(); template:Destroy()
return 'Disabled gait example installer validates rig and preserves existing scripts'
