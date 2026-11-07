-- Read-only comparison using Dino Auto's current edit-pose targets and raycasts.
local dino=workspace:FindFirstChild('Dino Auto')
assert(dino and dino.PrimaryPart,'Dino Auto and its PrimaryPart are required')
local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={dino}
local lines={}
for _,side in ipairs({'Left','Right'}) do
 local target=dino.IkTargets:FindFirstChild(side..' Target')
 local ray=dino.RaycastParts:FindFirstChild(side..' Raycast Part')
 assert(target and ray and target:IsA('BasePart') and ray:IsA('BasePart'),'missing target or ray part')
 local hit=workspace:Raycast(ray.Position,Vector3.new(0,-1000,0),params)
 assert(hit,'current edit-pose ray missed the ground')
 local previous=target:GetAttribute('PreviousPos') or Vector3.zero
 assert(typeof(previous)=='Vector3','PreviousPos must be a Vector3')
 local final=hit.Position+dino.PrimaryPart.CFrame.LookVector*2
 local originalMiddle=(final+previous)*.5+Vector3.new(0,1,0)
 local originalJump=(originalMiddle-target.Position).Magnitude
 local swing=StepTrajectory.new({start={target.Position.X,target.Position.Y,target.Position.Z},target={final.X,final.Y,final.Z},up={0,1,0},height=1,duration=.3})
 local first=swing:sample(0)
 local start=Vector3.new(first[1],first[2],first[3])
 assert((start-target.Position).Magnitude<1e-5,'swing must begin at current target')
 local last=swing:sample(.3)
 assert((Vector3.new(last[1],last[2],last[3])-final).Magnitude<1e-5,'swing must reach sampled destination')
 table.insert(lines,string.format('%s: first midpoint jump %.3f studs; smooth trajectory starts at current target',side,originalJump))
end
return table.concat(lines,'\n')
