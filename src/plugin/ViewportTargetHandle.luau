--!strict
-- A temporary world-space target with an axis-constrained Studio dragger.
local ViewportTargetHandle={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function point(value)
 return typeof(value)=='Vector3' and finite(value.X) and finite(value.Y) and finite(value.Z)
end
function ViewportTargetHandle.new(worldParent,guiParent,start,onRequest)
 assert(typeof(worldParent)=='Instance' and typeof(guiParent)=='Instance' and point(start) and type(onRequest)=='function','target parents, position and callback required')
 local anchor,endpoint,gizmo,gap=nil,nil,nil,nil
 local connections={}
 local dead=false
 local function cleanup()
  if dead then return end; dead=true
  for _,connection in ipairs(connections) do connection:Disconnect() end
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
  local dragOrigin,dragFace=nil,nil
  local api={}
  function api:isValid()
   return not dead and anchor.Parent==worldParent and endpoint.Parent==worldParent and gizmo.Parent==guiParent and gap.Parent==guiParent and gizmo.Adornee==anchor and gap.Adornee==anchor
  end
  function api:setPosition(value)
   assert(self:isValid() and point(value),'valid target position and preview resources required')
   anchor.CFrame=CFrame.new(value); refreshGap()
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
  function api:destroy() cleanup() end
  table.insert(connections,gizmo.MouseButton1Down:Connect(function(face) api:begin(face) end))
  table.insert(connections,gizmo.MouseDrag:Connect(function(face,distance) api:move(face,distance) end))
  table.insert(connections,gizmo.MouseButton1Up:Connect(function() api:finish() end))
  return api
 end)
 if not ok then cleanup(); error(result) end
 return result
end
return ViewportTargetHandle
