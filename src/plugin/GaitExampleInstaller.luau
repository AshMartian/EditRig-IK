--!strict
-- Prepare an inert, editable gait example; insertion is the caller's undoable action.
local Installer={}
function Installer.prepare(rig,template)
 assert(typeof(rig)=='Instance' and rig:IsA('Model') and rig.PrimaryPart,'select a model with a PrimaryPart')
 assert(not rig:FindFirstChild('EditRigIKSmoothGaitExample'),'gait example already exists; rename it first')
 local targets=rig:FindFirstChild('IkTargets'); local rays=rig:FindFirstChild('RaycastParts')
 assert(targets and rays,'model needs IkTargets and RaycastParts')
 for _,side in ipairs({'Left','Right'}) do
  local target=targets:FindFirstChild(side..' Target'); local ray=rays:FindFirstChild(side..' Raycast Part')
  assert(target and target:IsA('BasePart') and target.Anchored and ray and ray:IsA('BasePart'),'missing anchored target or ray part for '..side)
 end
 assert(typeof(template)=='Instance' and template:IsA('Script') and template.Disabled and template.Archivable,'disabled gait template unavailable')
 local module=template:FindFirstChild('DinoSmoothGait')
 assert(module and module:IsA('ModuleScript') and module.Archivable,'editable gait module unavailable')
 local copy=template:Clone(); assert(copy,'cannot clone gait template')
 copy.Name='EditRigIKSmoothGaitExample'; copy.Disabled=true
 return copy
end
return Installer
