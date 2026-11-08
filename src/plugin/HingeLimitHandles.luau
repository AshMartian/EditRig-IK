--!strict
-- Temporary hinge limit handles; all edits are draft callbacks, never rig writes.
local HingeLimitHandles={}
local axes={X=Vector3.xAxis,Y=Vector3.yAxis,Z=Vector3.zAxis}
local references={X=Vector3.yAxis,Y=Vector3.zAxis,Z=Vector3.xAxis}
-- Keep colors aligned with the local axes in AxisGizmo; shape and text also identify bounds.
local axisColors={X=Color3.fromRGB(255,75,75),Y=Color3.fromRGB(75,255,100),Z=Color3.fromRGB(80,145,255)}
function HingeLimitHandles.new(parent,mouse,Config,DragMath,restFrame,onDraft,onFocus)
 assert(typeof(parent)=='Instance' and mouse and type(restFrame)=='function' and type(onDraft)=='function','handle parent, mouse, rest frame and callback required')
 local lower=Instance.new('SphereHandleAdornment'); lower.Name='EditRigIKLowerHandle'; lower.Radius=.13
 local upper=Instance.new('BoxHandleAdornment'); upper.Name='EditRigIKUpperHandle'; upper.Size=Vector3.one*.23
 for _,handle in ipairs({lower,upper}) do
  handle.Archivable=false; handle.Color3=Color3.fromRGB(255,205,60); handle.AlwaysOnTop=true; handle.ZIndex=7; handle.Visible=false; handle.Parent=parent
 end
 local function makeLabel(bound,side)
  local gui=Instance.new('BillboardGui'); gui.Name='EditRigIK'..bound..'Label'; gui.Archivable=false
  gui.Size=UDim2.fromOffset(112,24); gui.SizeOffset=Vector2.new(side*.6,.75); gui.AlwaysOnTop=true; gui.Active=false; gui.Enabled=false
  local label=Instance.new('TextLabel'); label.Name='Label'; label.Size=UDim2.fromScale(1,1)
  label.BackgroundColor3=Color3.fromRGB(35,38,45); label.BackgroundTransparency=.15
  label.TextColor3=Color3.fromRGB(255,231,154); label.Font=Enum.Font.GothamMedium; label.TextSize=14
  label.TextStrokeTransparency=.7; label.Active=false; label.Parent=gui
  local corner=Instance.new('UICorner'); corner.CornerRadius=UDim.new(0,5); corner.Parent=label
  gui.Parent=parent; return gui
 end
 local lowerLabel=makeLabel('Lower',-1); local upperLabel=makeLabel('Upper',1)
 local dead=false; local joint=nil; local config=nil; local drag=nil; local selected=nil
 local connections={}
 local api={}
 local function hide()
  lower.Visible=false; lower.Adornee=nil; upper.Visible=false; upper.Adornee=nil
  lowerLabel.Enabled=false; lowerLabel.Adornee=nil; upperLabel.Enabled=false; upperLabel.Adornee=nil
 end
 local function point(angle)
  local axis=axes[config.axis]; local reference=references[config.axis]; local tangent=axis:Cross(reference)
  return reference*math.cos(math.rad(angle))+tangent*math.sin(math.rad(angle))
 end
 local function endpoints()
  if config.circular then
   return config.circular.start,(config.circular.start+config.circular.width+180)%360-180
  end
  return config.lower,config.upper
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
  lower.Color3=axisColors[config.axis]; upper.Color3=axisColors[config.axis]
  local lowerAngle,upperAngle=endpoints()
  local separation=(point(lowerAngle)-point(upperAngle)).Magnitude
  local upperRadius=if separation<.4 then 1.4 else 1
  for _,entry in ipairs({{lower,lowerAngle,1,lowerLabel,'Lower'},{upper,upperAngle,upperRadius,upperLabel,'Upper'}}) do
   local worldPoint=frame:PointToWorldSpace(point(entry[2])*entry[3])
   entry[1].Adornee=part
   entry[1].CFrame=part.CFrame:ToObjectSpace(CFrame.new(worldPoint))
   entry[1].Visible=true
   -- Despite its name, Studio applies this offset in the Adornee's rotated
   -- frame. Compensate so the rendered label stays at the endpoint. Roblox
   -- retains this behavior for compatibility: devforum topic 4527493.
   entry[4].Adornee=part; entry[4].StudsOffsetWorldSpace=part.CFrame:VectorToObjectSpace(worldPoint-part.Position)
   local display=if math.abs(entry[2])<.05 then 0 else entry[2]
   entry[4].Label.Text=string.format('%s %s %.1f°',entry[5],config.axis,display); entry[4].Enabled=true
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
   config.lower=previous.initialLower; config.upper=previous.initialUpper
   config.circular=previous.initialCircular
   local a,b=endpoints(); local value=if previous.bound=='lower' then a else b
   if self:update() then onDraft(previous.bound,value,previous.initialCircular,{lower=previous.initialLower,upper=previous.initialUpper}) end
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
   local a,b=config.circular,nextConfig.circular
   if (a==nil)~=(b==nil) or (a and (math.abs(a.start-b.start)>.001 or math.abs(a.width-b.width)>.001)) then same=false end
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
  local interval=config.circular or {start=config.lower,width=config.upper-config.lower}
  drag=DragMath.beginCircular(bound,interval.start,interval.width,pointer)
  drag.part=part; drag.frame=frame; drag.initialLower=config.lower; drag.initialUpper=config.upper
  drag.initialCircular=if config.circular then {start=config.circular.start,width=config.circular.width} else nil
  drag.promoted=false
  self:select(bound)
  if onFocus then onFocus(bound) end
  return true
 end
 function api:move(ray)
  if dead or not drag then return false end
  local pointer=pointerAngle(ray); if not pointer then return false end
  local bound=drag.bound; local start,width=DragMath.moveCircular(drag,pointer)
  local circular=config.circular~=nil or start+width>180+1e-7
  local value
  if circular then
   config.circular={start=start,width=width}
   config.lower=start; config.upper=(start+width+180)%360-180
   if not drag.initialCircular then drag.promoted=true end
   value=config[bound]
  else
   config.lower=start; config.upper=start+width
   value=config[bound]
  end
  if not self:update() then return false end
  onDraft(bound,value,config.circular)
  return true
 end
 function api:finish() self:cancel() end
 function api:destroy()
  if dead then return end
  dead=true; drag=nil
  for _,connection in ipairs(connections) do connection:Disconnect() end
  lower:Destroy(); upper:Destroy(); lowerLabel:Destroy(); upperLabel:Destroy()
 end
 table.insert(connections,lower.MouseButton1Down:Connect(function() api:begin('lower',mouse.UnitRay) end))
 table.insert(connections,upper.MouseButton1Down:Connect(function() api:begin('upper',mouse.UnitRay) end))
 table.insert(connections,mouse.Move:Connect(function() api:move(mouse.UnitRay) end))
 table.insert(connections,mouse.Button1Up:Connect(function() api:finish() end))
 return api
end
return HingeLimitHandles
