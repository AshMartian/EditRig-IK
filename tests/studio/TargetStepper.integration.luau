local model=Instance.new('Model')
local part=Instance.new('Part'); part.Anchored=true; part.Position=Vector3.new(4,1,2); part.Parent=model
local parent=Instance.new('Part'); parent.Anchored=true; parent.CFrame=CFrame.new(10,0,0)*CFrame.Angles(0,0,.4); parent.Parent=model
local attachment=Instance.new('Attachment'); attachment.Position=Vector3.new(1,2,0); attachment.Parent=parent
local ownership=Ownership.new()
local function position(target) return if target:IsA('Attachment') then target.WorldPosition else target.Position end
for _,target in ipairs({part,attachment}) do
 local start=position(target); local finish=start+Vector3.new(2,0,0)
 local stepper=TargetStepper.new(target,{exclusive=true,up=Vector3.yAxis,height=1,duration=1,ownership=ownership},StepTrajectory)
 assert(not pcall(function() TargetStepper.new(target,{exclusive=true,up=Vector3.yAxis,height=1,duration=1,ownership=ownership},StepTrajectory) end),'duplicate ownership must be rejected')
 stepper:requestStep(finish)
 local result=stepper:step(.5)
 assert(result.moving and (position(target)-(start+Vector3.new(1,1,0))).Magnitude<1e-4,'target should follow smooth midpoint')
 local retarget=position(target)+Vector3.new(0,0,2)
 stepper:requestStep(retarget); local atRetarget=position(target); stepper:step(0)
 assert((position(target)-atRetarget).Magnitude<1e-4,'retarget must begin without a jump')
 result=stepper:step(1)
 assert(not result.moving and (position(target)-retarget).Magnitude<1e-4,'target should reach retargeted destination')
 target.Position+=Vector3.xAxis
 assert(not pcall(function() stepper:step(.1) end),'external writes must be detected')
 stepper:destroy(); stepper:destroy()
 assert(not pcall(function() stepper:step(.1) end),'destroyed driver must reject calls')
 local replacement=TargetStepper.new(target,{exclusive=true,up=Vector3.yAxis,height=1,duration=1,ownership=ownership},StepTrajectory); replacement:destroy()
end
local movingParent=TargetStepper.new(attachment,{exclusive=true,up=Vector3.yAxis,height=1,duration=1,ownership=ownership},StepTrajectory)
local from=attachment.WorldPosition
movingParent:requestStep(from+Vector3.new(2,0,0))
parent.CFrame+=Vector3.new(0,3,0)
local state=movingParent:step(.5)
assert((state.position-(from+Vector3.new(1,1,0))).Magnitude<1e-4 and (attachment.WorldPosition-state.position).Magnitude<1e-4,'moving attachment parent must preserve world trajectory')
movingParent:destroy()
local moving=Instance.new('Part'); moving.Parent=model
assert(not pcall(function() TargetStepper.new(moving,{exclusive=true,up=Vector3.yAxis,height=1,duration=1,ownership=ownership},StepTrajectory) end),'unanchored target parts must be rejected')
model:Destroy()
return 'Target stepper moves and retargets parts and attachments, detects conflicts, releases ownership'
