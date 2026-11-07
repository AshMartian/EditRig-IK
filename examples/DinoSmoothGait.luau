--!strict
-- Explicit, experimental two-foot target scheduler for a Dino Auto-like model.
-- This does not change or disable any existing script, IKControl, or Animator.
local SmoothGait={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function SmoothGait.new(rig,IK,settings,sampleGround)
 assert(typeof(rig)=='Instance' and rig:IsA('Model') and rig.PrimaryPart,'model with PrimaryPart required')
 assert(type(IK)=='table' and type(IK.createTargetStepper)=='function','runtime target stepper required')
 assert(type(settings)=='table' and finite(settings.distance) and settings.distance>=0 and finite(settings.forward),'valid step distance and forward offset required')
 local targets=rig:FindFirstChild('IkTargets'); local rayParts=rig:FindFirstChild('RaycastParts')
 assert(targets and rayParts,'model must have IkTargets and RaycastParts')
 local legs={}
 for _,side in ipairs({'Left','Right'}) do
  local target=targets:FindFirstChild(side..' Target'); local ray=rayParts:FindFirstChild(side..' Raycast Part')
  assert(target and target:IsA('BasePart') and target.Anchored and ray and ray:IsA('BasePart'),'missing anchored target or ray part for '..side)
  legs[side]={target=target,ray=ray,planted=target.Position}
 end
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={rig}
 local sample=sampleGround or function(_,ray)
  local hit=workspace:Raycast(ray.Position,Vector3.new(0,-1000,0),params)
  return if hit then hit.Position else nil
 end
 assert(type(sample)=='function','ground sampler must be a function')
 local opts={exclusive=true,up=Vector3.yAxis,height=settings.height,duration=settings.duration}
 local left=IK.createTargetStepper(legs.Left.target,opts)
 local ok,right=pcall(IK.createTargetStepper,legs.Right.target,opts)
 if not ok then left:destroy(); error(right) end
 legs.Left.mover=left; legs.Right.mover=right
 local nextSide='Left'; local active=nil; local dead=false
 local api={}
 function api:step(dt)
  assert(not dead,'gait is destroyed')
  assert(finite(dt) and dt>=0,'invalid delta time')
  if not active then
   local order={nextSide,if nextSide=='Left' then 'Right' else 'Left'}
   for _,side in ipairs(order) do
    local leg=legs[side]; local hit=sample(side,leg.ray)
    assert(hit==nil or (typeof(hit)=='Vector3' and finite(hit.X) and finite(hit.Y) and finite(hit.Z)),'ground sampler returned an invalid position')
    if hit and (hit-leg.planted).Magnitude>settings.distance then
     local destination=hit+rig.PrimaryPart.CFrame.LookVector*settings.forward
     leg.mover:requestStep(destination); leg.destination=destination; active=side
     break
    end
   end
  end
  if active then
   local side=active; local leg=legs[side]; local state=leg.mover:step(dt)
   if not state.moving then
    leg.planted=leg.destination; active=nil; nextSide=if side=='Left' then 'Right' else 'Left'
   end
  end
  return {swinging=active}
 end
 function api:destroy()
  if dead then return end
  dead=true
  left:destroy(); right:destroy()
 end
 return api
end
return SmoothGait
