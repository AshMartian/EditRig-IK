--!strict
-- A temporary world-space target with an axis-constrained Studio dragger.
local ViewportTargetHandle={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function point(value)
 return typeof(value)=='Vector3' and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function frame(value)
 if typeof(value)~='CFrame' then return false end
 for _,component in ipairs({value:GetComponents()}) do if not finite(component) then return false end end
 return true
end
local axisVector={ [Enum.Axis.X]=Vector3.xAxis, [Enum.Axis.Y]=Vector3.yAxis, [Enum.Axis.Z]=Vector3.zAxis }
function ViewportTargetHandle.new(worldParent,guiParent,start,onRequest,options)
 options=options or {}
 assert(type(options)=='table' and (options.orientation==nil or frame(options.orientation)) and (options.onOrientation==nil or type(options.onOrientation)=='function'),'valid orientation options required')
 assert(typeof(worldParent)=='Instance' and typeof(guiParent)=='Instance' and point(start) and type(onRequest)=='function','target parents, position and callback required')
 local anchor,endpoint,gizmo,gap,rotationAnchor,rings=nil,nil,nil,nil,nil,nil
 local connections={}
 local dead=false
 local function cleanup()
  if dead then return end; dead=true
  for _,connection in ipairs(connections) do connection:Disconnect() end
  if rings then rings:Destroy() end
  if rotationAnchor then rotationAnchor:Destroy() end
  if gap then gap:Destroy() end
  if gizmo then gizmo:Destroy() end
  if endpoint then endpoint:Destroy() end
  if anchor then anchor:Destroy() end
 end
 local ok,result=pcall(function()
  anchor=Instance.new('Part'); anchor.Name='EditRigIKPreviewTarget'; anchor.Archivable=false
  anchor.Size=Vector3.one*.3; anchor.Shape=Enum.PartType.Block; anchor.Material=Enum.Material.Neon
  anchor.Color=Color3.fromRGB(255,95,85); anchor.Transparency=.15; anchor.Anchored=true
  anchor.CanCollide=false; anchor.CanTouch=false; anchor.CanQuery=false; anchor.CastShadow=false; anchor.Locked=true
  anchor.CFrame=CFrame.new(start); anchor.Parent=worldParent
  endpoint=Instance.new('Part'); endpoint.Name='EditRigIKPreviewEndpoint'; endpoint.Archivable=false
  endpoint.Size=Vector3.one*.2; endpoint.Shape=Enum.PartType.Ball; endpoint.Material=Enum.Material.Neon
  endpoint.Color=Color3.fromRGB(100,255,145); endpoint.Anchored=true
  endpoint.CanCollide=false; endpoint.CanTouch=false; endpoint.CanQuery=false; endpoint.CastShadow=false; endpoint.Locked=true
  endpoint.CFrame=CFrame.new(start); endpoint.Parent=worldParent
  gap=Instance.new('LineHandleAdornment'); gap.Name='EditRigIKPreviewGap'; gap.Archivable=false
  gap.Color3=Color3.fromRGB(255,205,80); gap.Thickness=3; gap.AlwaysOnTop=true; gap.ZIndex=6; gap.Visible=false; gap.Adornee=anchor; gap.Parent=guiParent
  local function refreshGap()
   local localEndpoint=anchor.CFrame:PointToObjectSpace(endpoint.Position)
   local distance=localEndpoint.Magnitude
   gap.Visible=distance>1e-4
   if gap.Visible then
    gap.CFrame=CFrame.lookAt(Vector3.zero,localEndpoint); gap.Length=distance
   end
  end
  gizmo=Instance.new('Handles'); gizmo.Name='EditRigIKTargetHandles'; gizmo.Archivable=false
  gizmo.Style=Enum.HandlesStyle.Movement; gizmo.Color3=Color3.fromRGB(255,115,95)
  gizmo.Faces=Faces.new(Enum.NormalId.Right,Enum.NormalId.Top,Enum.NormalId.Front)
  gizmo.Adornee=anchor; gizmo.Parent=guiParent
  -- Keep the rotation frame separate from the translation anchor. Handles use
  -- their adornee's local frame; the movement gizmo must remain world-aligned.
  rotationAnchor=Instance.new('Part'); rotationAnchor.Name='EditRigIKPreviewOrientation'; rotationAnchor.Archivable=false
  rotationAnchor.Size=Vector3.one*.3; rotationAnchor.Transparency=1; rotationAnchor.Anchored=true
  rotationAnchor.CanCollide=false; rotationAnchor.CanTouch=false; rotationAnchor.CanQuery=false; rotationAnchor.CastShadow=false; rotationAnchor.Locked=true
  rotationAnchor.CFrame=CFrame.new(start)*(options.orientation or CFrame.identity).Rotation; rotationAnchor.Parent=worldParent
  rings=Instance.new('ArcHandles'); rings.Name='EditRigIKTargetRotationHandles'; rings.Archivable=false
  rings.Axes=Axes.new(Enum.Axis.X,Enum.Axis.Y,Enum.Axis.Z); rings.Adornee=rotationAnchor; rings.Visible=false; rings.Parent=guiParent
  local dragOrigin,dragFace=nil,nil
  local rotationOrigin,rotationAxis=nil,nil
  local mode='move'
  local api={}
  function api:isValid()
   return not dead and anchor.Parent==worldParent and endpoint.Parent==worldParent and gizmo.Parent==guiParent and gap.Parent==guiParent and gizmo.Adornee==anchor and gap.Adornee==anchor and rotationAnchor.Parent==worldParent and rings.Parent==guiParent and rings.Adornee==rotationAnchor
  end
  function api:setPosition(value)
   assert(self:isValid() and point(value),'valid target position and preview resources required')
   anchor.CFrame=CFrame.new(value); rotationAnchor.CFrame=CFrame.new(value)*rotationAnchor.CFrame.Rotation; refreshGap()
  end
  function api:setEndpoint(value)
   assert(self:isValid() and point(value),'valid endpoint position and preview resources required')
   endpoint.CFrame=CFrame.new(value); refreshGap()
  end
  function api:begin(face)
   assert(self:isValid() and typeof(face)=='EnumItem' and face.EnumType==Enum.NormalId,'valid drag face and preview resources required')
   dragOrigin=anchor.Position; dragFace=face
  end
  function api:move(face,distance)
   assert(self:isValid() and finite(distance),'finite drag distance and preview resources required')
   if dragOrigin and dragFace==face then onRequest(dragOrigin+Vector3.FromNormalId(face)*distance) end
  end
  function api:finish() dragOrigin=nil; dragFace=nil end
  function api:setOrientation(value)
   assert(self:isValid() and frame(value),'valid target orientation and preview resources required')
   rotationAnchor.CFrame=CFrame.new(anchor.Position)*value.Rotation
  end
  function api:setMode(value)
   assert(self:isValid() and (value=='move' or value=='rotate'),'valid preview mode required')
   assert(value~='rotate' or options.onOrientation,'orientation callback required for rotation mode')
   mode=value; dragOrigin=nil; dragFace=nil; rotationOrigin=nil; rotationAxis=nil
   gizmo.Visible=value=='move'; rings.Visible=value=='rotate'
  end
  function api:beginRotation(axis)
   assert(self:isValid() and axisVector[axis] and mode=='rotate','valid rotation axis and active rotation mode required')
   rotationOrigin=rotationAnchor.CFrame.Rotation; rotationAxis=axis
  end
  function api:moveRotation(axis,angle)
   assert(self:isValid() and finite(angle),'finite rotation angle and preview resources required')
   if mode=='rotate' and rotationOrigin and rotationAxis==axis then
    options.onOrientation(rotationOrigin*CFrame.fromAxisAngle(axisVector[axis],angle))
   end
  end
  function api:finishRotation() rotationOrigin=nil; rotationAxis=nil end
  function api:destroy() cleanup() end
  table.insert(connections,gizmo.MouseButton1Down:Connect(function(face) api:begin(face) end))
  table.insert(connections,gizmo.MouseDrag:Connect(function(face,distance) api:move(face,distance) end))
  table.insert(connections,gizmo.MouseButton1Up:Connect(function() api:finish() end))
  table.insert(connections,rings.MouseButton1Down:Connect(function(axis) api:beginRotation(axis) end))
  table.insert(connections,rings.MouseDrag:Connect(function(axis,angle) api:moveRotation(axis,angle) end))
  table.insert(connections,rings.MouseButton1Up:Connect(function() api:finishRotation() end))
  return api
 end)
 if not ok then cleanup(); error(result) end
 return result
end
return ViewportTargetHandle
