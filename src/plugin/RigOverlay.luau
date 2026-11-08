--!strict
-- Temporary Studio adornments; never insert visualization objects into the rig.
local RigOverlay={}
local function finite(value)
 return type(value)=='number' and value==value and math.abs(value)<math.huge
end
function RigOverlay.radiusFromProjection(pixelsPerStud,selected)
 if not finite(pixelsPerStud) or pixelsPerStud<=0 then return if selected then .22 else .16 end
 local radius=math.clamp(7/pixelsPerStud,.04,.4)
 return if selected then math.min(radius*1.4,.5) else radius
end
local function anchorAndPosition(joint,rig)
 if not joint:IsDescendantOf(rig) then return nil,nil end
 if joint:IsA('Motor6D') then
  local part=joint.Part0
  if part and part:IsDescendantOf(rig) then return part,(part.CFrame*joint.C0).Position end
 elseif joint:IsA('Bone') then
  local part=joint.Parent
  while part and not part:IsA('BasePart') do part=part.Parent end
  if part and part:IsDescendantOf(rig) then return part,joint.TransformedWorldCFrame.Position end
 end
 return nil,nil
end
function RigOverlay.new(rig,holder,onSelect)
 assert(typeof(rig)=='Instance' and rig:IsA('Model') and rig:IsDescendantOf(workspace),'select a model in Workspace')
 assert(typeof(holder)=='Instance' and type(onSelect)=='function','overlay holder and selection callback required')
 local joints={}
 for _,item in ipairs(rig:GetDescendants()) do
  if item:IsA('Motor6D') or item:IsA('Bone') then table.insert(joints,item) end
 end
 assert(#joints>0 and #joints<=300,'model must have 1 to 300 joints')
 local entries,motorByPart={},{}
 for _,joint in ipairs(joints) do
  if joint:IsA('Motor6D') and joint.Part1 then
   if motorByPart[joint.Part1]==nil then motorByPart[joint.Part1]=joint else motorByPart[joint.Part1]=false end
  end
 end
 for _,joint in ipairs(joints) do
  local marker=Instance.new('SphereHandleAdornment'); marker.Name='EditRigIKJoint'
  marker.Radius=.16; marker.Color3=Color3.fromRGB(75,205,255); marker.AlwaysOnTop=true; marker.ZIndex=5
  marker.Parent=holder
  local line=Instance.new('WireframeHandleAdornment'); line.Name='EditRigIKLink'
  line.Color3=Color3.fromRGB(45,170,230); line.Thickness=2; line.AlwaysOnTop=true; line.ZIndex=4; line.Parent=holder
  local connection=marker.MouseButton1Down:Connect(function()
   if joint:IsDescendantOf(rig) then onSelect(joint) end
  end)
  table.insert(entries,{joint=joint,marker=marker,line=line,connection=connection})
 end
 local selectedOutline=Instance.new('WireframeHandleAdornment'); selectedOutline.Name='EditRigIKSelectedOutline'
 selectedOutline.Color3=Color3.fromRGB(255,245,205); selectedOutline.Thickness=2
 selectedOutline.AlwaysOnTop=true; selectedOutline.ZIndex=6; selectedOutline.Parent=holder
 local dead=false
 local api={}
 function api:count() return #entries end
 function api:update(selected)
  assert(not dead,'overlay is destroyed')
  local camera=workspace.CurrentCamera
  selectedOutline:Clear(); selectedOutline.Adornee=nil
  for _,entry in ipairs(entries) do
   local joint=entry.joint
   local part,position=anchorAndPosition(joint,rig)
   local marker,line=entry.marker,entry.line
   marker.Adornee=part
   marker.Color3=if joint==selected then Color3.fromRGB(255,205,70) else Color3.fromRGB(75,205,255)
   if part then
    if camera then
     -- Sampling the actual projection handles perspective, orthographic,
     -- FOV modes and viewport stretching without guessing the camera mode.
     local screen=camera:WorldToViewportPoint(position)
     local screenUp=camera:WorldToViewportPoint(position+camera.CFrame.UpVector)
     marker.Radius=RigOverlay.radiusFromProjection(math.abs(screenUp.Y-screen.Y),joint==selected)
    else marker.Radius=if joint==selected then .22 else .16 end
    marker.CFrame=CFrame.new(part.CFrame:PointToObjectSpace(position))
    if joint==selected then
     local right=if camera then camera.CFrame.RightVector else Vector3.xAxis
     local up=if camera then camera.CFrame.UpVector else Vector3.yAxis
     local r=marker.Radius*1.55
     local previous=position+right*r
     for i=1,24 do
      local angle=2*math.pi*i/24
      local nextPoint=position+(right*math.cos(angle)+up*math.sin(angle))*r
      selectedOutline:AddLine(previous,nextPoint); previous=nextPoint
     end
     selectedOutline.Adornee=part
    end
   end
   local parentJoint=if joint:IsA('Bone') and joint.Parent and joint.Parent:IsA('Bone') then joint.Parent elseif joint:IsA('Motor6D') then motorByPart[joint.Part0] else nil
   local parentPosition=nil
   if parentJoint then local _,point=anchorAndPosition(parentJoint,rig); parentPosition=point end
   line:Clear(); line.Adornee=nil
   if part and parentPosition and parentJoint~=joint then
    -- In Studio these wireframe points render in world coordinates, unlike
    -- the sphere marker's part-relative CFrame.
    line:AddLine(position,parentPosition); line.Adornee=part
   end
  end
 end
 function api:destroy()
  if dead then return end; dead=true
  for _,entry in ipairs(entries) do entry.connection:Disconnect(); entry.marker:Destroy(); entry.line:Destroy() end
  selectedOutline:Destroy()
 end
 return api
end
return RigOverlay
