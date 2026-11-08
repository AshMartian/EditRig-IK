--!strict
-- Temporary hinge limit handles; all edits are draft callbacks, never rig writes.
local HingeLimitHandles={}
local axes={X=Vector3.xAxis,Y=Vector3.yAxis,Z=Vector3.zAxis}
local references={X=Vector3.yAxis,Y=Vector3.zAxis,Z=Vector3.xAxis}
function HingeLimitHandles.new(parent,mouse,Config,DragMath,restFrame,onDraft,onFocus)
 assert(typeof(parent)=='Instance' and mouse and type(restFrame)=='function' and type(onDraft)=='function','handle parent, mouse, rest frame and callback required')
 local lower=Instance.new('SphereHandleAdornment'); lower.Name='EditRigIKLowerHandle'; lower.Radius=.13
 local upper=Instance.new('BoxHandleAdornment'); upper.Name='EditRigIKUpperHandle'; upper.Size=Vector3.one*.23
 for _,handle in ipairs({lower,upper}) do
  handle.Archivable=false; handle.Color3=Color3.fromRGB(255,205,60); handle.AlwaysOnTop=true; handle.ZIndex=7; handle.Visible=false; handle.Parent=parent
 end
 local dead=false; local joint=nil; local config=nil; local drag=nil; local selected=nil
 local connections={}
 local api={}
 local function hide()
  lower.Visible=false; lower.Adornee=nil; upper.Visible=false; upper.Adornee=nil
 end
 local function point(angle)
  local axis=axes[config.axis]; local reference=references[config.axis]; local tangent=axis:Cross(reference)
  return reference*math.cos(math.rad(angle))+tangent*math.sin(math.rad(angle))
 end
 local function sameFrame(part,frame)
  if not drag then return true end
  return part==drag.part and (frame.Position-drag.frame.Position).Magnitude<1e-5
   and (frame.RightVector-drag.frame.RightVector).Magnitude<1e-5
   and (frame.UpVector-drag.frame.UpVector).Magnitude<1e-5
 end
 function api:select(bound)
  assert(bound==nil or bound=='lower' or bound=='upper','unknown hinge bound')
  if dead then return false end
  selected=bound
  lower.Radius=if bound=='lower' then .18 else .13
  upper.Size=Vector3.one*(if bound=='upper' then .33 else .23)
  return true
 end
 function api:update()
  if dead then return false end
  if not joint or not config then hide(); return false end
  local part,frame=restFrame(joint)
  if not part or not frame then hide(); self:cancel(); return false end
  if not sameFrame(part,frame) then self:cancel() end
  local separation=(point(config.lower)-point(config.upper)).Magnitude
  local upperRadius=if separation<.4 then 1.4 else 1
  for _,entry in ipairs({{lower,config.lower,1},{upper,config.upper,upperRadius}}) do
   entry[1].Adornee=part
   entry[1].CFrame=part.CFrame:ToObjectSpace(CFrame.new(frame:PointToWorldSpace(point(entry[2])*entry[3])))
   entry[1].Visible=true
  end
  return true
 end
 function api:cancel(restore)
  local previous=drag
  local canRestore=false
  if restore and previous and config and joint and not dead then
   local part,frame=restFrame(joint)
   canRestore=part~=nil and frame~=nil and sameFrame(part,frame)
  end
  drag=nil
  if canRestore then
   config[previous.bound]=previous.initial
   if self:update() then onDraft(previous.bound,previous.initial) end
  end
 end
 function api:set(nextJoint,input)
  assert(not dead,'hinge handles are destroyed')
  self:cancel()
  if nextJoint~=joint then self:select(nil) end
  joint=nil; config=nil; hide()
  local ok,result=pcall(Config.validate,input)
  if not ok or result.kind~='Hinge' or not nextJoint then return false end
  joint=nextJoint; config=result
  return self:update()
 end
 function api:sync(nextJoint,input)
  if dead then return false end
  local ok,nextConfig=pcall(Config.validate,input)
  local same=ok and drag and nextJoint==joint and nextConfig.kind==config.kind and nextConfig.axis==config.axis
  if same then
   for _,key in ipairs({'lower','upper','swing','weight'}) do
    if math.abs(nextConfig[key]-config[key])>0.001 then same=false; break end
   end
  end
  if same then return self:update() end
  return self:set(nextJoint,input)
 end
 local function pointerAngle(ray)
  if typeof(ray)~='Ray' or not joint or not config then return nil end
  local part,frame=restFrame(joint); if not part or not frame then api:cancel(); hide(); return nil end
  if not sameFrame(part,frame) then api:cancel(); return nil end
  local origin=frame:PointToObjectSpace(ray.Origin)
  local direction=frame:VectorToObjectSpace(ray.Direction)
  local axis=axes[config.axis]; local reference=references[config.axis]; local tangent=axis:Cross(reference)
  local denominator=direction:Dot(axis)
  if math.abs(denominator)<1e-5 then return nil end
  local distance=-origin:Dot(axis)/denominator
  if distance<0 then return nil end
  local hit=origin+direction*distance
  local x,y=hit:Dot(reference),hit:Dot(tangent)
  if x*x+y*y<1e-8 then return nil end
  return math.deg(math.atan2(y,x))
 end
 function api:begin(bound,ray)
  if dead or not config or (bound~='lower' and bound~='upper') then return false end
  local pointer=pointerAngle(ray)
  if not pointer then return false end
  local part,frame=restFrame(joint)
  if not part or not frame then return false end
  drag=DragMath.begin(bound,config.lower,config.upper,pointer)
  drag.part=part; drag.frame=frame; drag.initial=config[bound]
  self:select(bound)
  if onFocus then onFocus(bound) end
  return true
 end
 function api:move(ray)
  if dead or not drag then return false end
  local pointer=pointerAngle(ray); if not pointer then return false end
  local bound=drag.bound; local value=DragMath.move(drag,pointer)
  config[bound]=value
  if not self:update() then return false end
  onDraft(bound,value)
  return true
 end
 function api:finish() self:cancel() end
 function api:destroy()
  if dead then return end
  dead=true; drag=nil
  for _,connection in ipairs(connections) do connection:Disconnect() end
  lower:Destroy(); upper:Destroy()
 end
 table.insert(connections,lower.MouseButton1Down:Connect(function() api:begin('lower',mouse.UnitRay) end))
 table.insert(connections,upper.MouseButton1Down:Connect(function() api:begin('upper',mouse.UnitRay) end))
 table.insert(connections,mouse.Move:Connect(function() api:move(mouse.UnitRay) end))
 table.insert(connections,mouse.Button1Up:Connect(function() api:finish() end))
 return api
end
return HingeLimitHandles
