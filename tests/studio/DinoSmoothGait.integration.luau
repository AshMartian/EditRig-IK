local source=workspace:FindFirstChild('Dino Auto')
assert(source and source.Archivable,'Dino Auto must be available')
local rig=source:Clone()
local ownership=Ownership.new()
local runtime={createTargetStepper=function(target,options)
 local copy=table.clone(options); copy.ownership=ownership
 return TargetStepper.new(target,copy,StepTrajectory)
end}
local rays={}
local gait=SmoothGait.new(rig,runtime,{distance=1,forward=0,height=1,duration=1},function(side,ray)
 return rays[side]
end)
local left=rig.IkTargets:FindFirstChild('Left Target')
local right=rig.IkTargets:FindFirstChild('Right Target')
local leftStart,rightStart=left.Position,right.Position
rays.Left=leftStart+Vector3.new(2,0,0); rays.Right=rightStart+Vector3.new(2,0,0)
local first=gait:step(0)
assert(first.swinging=='Left' and (left.Position-leftStart).Magnitude<1e-5,'first step must start at current target')
local middle=gait:step(.5)
assert(middle.swinging=='Left' and (left.Position-(leftStart+Vector3.new(1,1,0))).Magnitude<1e-4,'left target should move smoothly')
assert((right.Position-rightStart).Magnitude<1e-5,'other foot remains planted')
gait:step(.5)
assert((left.Position-rays.Left).Magnitude<1e-4,'left foot should land')
local next=gait:step(0)
assert(next.swinging=='Right' and (right.Position-rightStart).Magnitude<1e-5,'right foot should start only after left lands')
gait:step(1)
assert((right.Position-rays.Right).Magnitude<1e-4,'right foot should land')
gait:destroy(); gait:destroy()
assert(not pcall(function() gait:step(.1) end),'destroyed gait must reject updates')
rig:Destroy()
return 'Dino clone alternates smooth targets without initial origin jump'
