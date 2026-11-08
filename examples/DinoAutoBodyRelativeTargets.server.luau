--!strict
-- OPTIONAL EXPERIMENT: place this Script directly under Workspace.Dino Auto.
-- Keeps both existing Transform IK target rotations relative to HumanoidRootPart.
-- Target positions are preserved. This also rotates a planted foot; it is not
-- a planted-foot gait, terrain alignment, a joint-limit fix, or a solver.
-- Disable or remove this Script to stop. Resolve any other target-rotation
-- writer before enabling it; this Script stops if it observes one.
local RunService = game:GetService('RunService')
local rig = script.Parent
local function fail(reason: string)
 warn('[DinoAutoBodyRelativeTargets] '..reason..'; target rotation updates stopped.')
end
if not rig or not rig:IsA('Model') or rig.Name~='Dino Auto' or not rig:IsDescendantOf(workspace) then
 fail('Place this Script directly under the Dino Auto model in Workspace')
 return
end
local body = rig:FindFirstChild('HumanoidRootPart')
local humanoid = rig:FindFirstChildOfClass('Humanoid')
local targets = rig:FindFirstChild('IkTargets')
if not body or not body:IsA('BasePart') or not humanoid or not targets or not targets:IsA('Folder') then
 fail('HumanoidRootPart, Humanoid, or IkTargets folder is missing')
 return
end
local entries = {}
for _,side in ipairs({'Left','Right'}) do
 local target = targets:FindFirstChild(side..' Target')
 if not target or not target:IsA('BasePart') or not target.Anchored then
  fail(side..' Target must be an anchored BasePart in IkTargets')
  return
 end
 local found = nil
 for _,item in ipairs(humanoid:GetDescendants()) do
  if item:IsA('IKControl') and item.Target==target and item.Enabled and item.Type==Enum.IKControlType.Transform then
   if found then fail('More than one Transform IKControl references '..target.Name); return end
   found=item
  end
 end
 if not found then fail('No enabled Transform IKControl references '..target.Name); return end
 local rotation=target.CFrame.Rotation
 table.insert(entries,{target=target,control=found,relative=body.CFrame.Rotation:Inverse()*rotation,last=rotation})
end
local connection
local function stop(reason: string)
 if connection then connection:Disconnect(); connection=nil end
 fail(reason)
end
connection=RunService.PreAnimation:Connect(function()
 if script.Disabled or script.Parent~=rig or not rig:IsDescendantOf(workspace) or body.Parent~=rig or targets.Parent~=rig or humanoid.Parent~=rig then
  stop('Rig or Script changed')
  return
 end
 -- Check both sides before writing either, so a changed setup never results in
 -- one foot being updated while the other silently keeps an outdated heading.
 for _,entry in ipairs(entries) do
  if entry.target.Parent~=targets or not entry.target.Anchored or not entry.control:IsDescendantOf(humanoid) or not entry.control.Enabled or entry.control.Type~=Enum.IKControlType.Transform or entry.control.Target~=entry.target then
   stop('Target or IKControl changed')
   return
  end
  if not entry.target.CFrame.Rotation:FuzzyEq(entry.last,1e-4) then
   stop('Another writer changed '..entry.target.Name..' rotation')
   return
  end
 end
 for _,entry in ipairs(entries) do
  local rotation=body.CFrame.Rotation*entry.relative
  entry.target.CFrame=CFrame.new(entry.target.Position)*rotation
  entry.last=entry.target.CFrame.Rotation
 end
end)
script.Destroying:Connect(function()
 if connection then connection:Disconnect(); connection=nil end
end)
