--!strict
-- Temporary rest-axis markers. Never parent them to the edited model.
local AxisGizmo={}
function AxisGizmo.new(parent,geometry)
 local lines={}
 for _,spec in ipairs({
  {name='X',axis=Vector3.xAxis,color=Color3.fromRGB(255,75,75)},
  {name='Y',axis=Vector3.yAxis,color=Color3.fromRGB(75,255,100)},
  {name='Z',axis=Vector3.zAxis,color=Color3.fromRGB(80,145,255)},
 }) do
  local line=Instance.new('WireframeHandleAdornment')
  line.Name='EditRigIKAxis'..spec.name
  line.Color3=spec.color; line.AlwaysOnTop=true; line.ZIndex=1
  line:AddLine(Vector3.zero,spec.axis*1.5)
  line.Parent=parent
  table.insert(lines,line)
 end
 local limit=Instance.new('WireframeHandleAdornment')
 limit.Name='EditRigIKLimit'; limit.Color3=Color3.fromRGB(255,210,60)
 limit.Thickness=2; limit.AlwaysOnTop=true; limit.ZIndex=1; limit.Parent=parent
 local hasLimits=false
 local dead=false
 local api={}
 function api:clear()
  if not dead then for _,line in ipairs(lines) do line.Adornee=nil end; limit.Adornee=nil end
 end
 function api:setLimits(config)
  assert(not dead,'axis gizmo is destroyed')
  local ok,segments=pcall(geometry.build,config)
  limit:Clear(); limit.Adornee=nil; hasLimits=false
  if not ok then return false end
  for _,segment in ipairs(segments) do limit:AddLine(segment[1],segment[2]) end
  hasLimits=true
  return true
 end
 function api:update(joint)
  assert(not dead,'axis gizmo is destroyed')
  local part,frame=nil,nil
  if joint and joint:IsA('Motor6D') and joint.Part0 then
   part=joint.Part0; frame=part.CFrame*joint.C0
  elseif joint and joint:IsA('Bone') then
   local parentJoint=joint.Parent
   if parentJoint and (parentJoint:IsA('Bone') or parentJoint:IsA('BasePart')) then
    frame=(if parentJoint:IsA('Bone') then parentJoint.TransformedWorldCFrame else parentJoint.CFrame)*joint.CFrame
    local ancestor=parentJoint
    while ancestor and not ancestor:IsA('BasePart') do ancestor=ancestor.Parent end
    part=ancestor
   end
  end
  if not part or not frame then self:clear(); return false end
  local offset=part.CFrame:ToObjectSpace(frame)
  for _,line in ipairs(lines) do line.Adornee=part; line.CFrame=offset end
  if hasLimits then limit.Adornee=part; limit.CFrame=offset end
  return true
 end
 function api:destroy()
  if dead then return end
  dead=true
  for _,line in ipairs(lines) do line:Destroy() end
  limit:Destroy()
 end
 return api
end
return AxisGizmo
