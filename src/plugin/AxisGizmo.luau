--!strict
-- Temporary rest-axis markers. Never parent them to the edited model.
local AxisGizmo={}
function AxisGizmo.toWorldSegments(frame,segments)
 local result={}
 for _,segment in ipairs(segments) do
  table.insert(result,{frame:PointToWorldSpace(segment[1]),frame:PointToWorldSpace(segment[2])})
 end
 return result
end
function AxisGizmo.new(parent,geometry,limitOnly)
 local lines={}
 for _,spec in ipairs(if limitOnly then {} else {
  {name='X',axis=Vector3.xAxis,color=Color3.fromRGB(255,75,75)},
  {name='Y',axis=Vector3.yAxis,color=Color3.fromRGB(75,255,100)},
  {name='Z',axis=Vector3.zAxis,color=Color3.fromRGB(80,145,255)},
 }) do
  local line=Instance.new('WireframeHandleAdornment')
  line.Name='EditRigIKAxis'..spec.name
  line.Color3=spec.color; line.Thickness=3; line.AlwaysOnTop=true; line.ZIndex=1
  line.Parent=parent
  table.insert(lines,{adornment=line,axis=spec.axis})
 end
 local limit=Instance.new('WireframeHandleAdornment')
 limit.Name='EditRigIKLimit'; limit.Color3=Color3.fromRGB(255,210,60)
 limit.Thickness=2; limit.AlwaysOnTop=true; limit.ZIndex=1; limit.Parent=parent
 local segments=nil
 local dead=false
 local api={}
 function api:clear()
  if not dead then for _,line in ipairs(lines) do line.adornment.Adornee=nil end; limit.Adornee=nil end
 end
 function api:setLimits(config)
  assert(not dead,'axis gizmo is destroyed')
  local ok,result=pcall(geometry.build,config)
  limit:Clear(); limit.Adornee=nil; segments=nil
  if not ok then return false end
  segments=result
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
  for _,line in ipairs(lines) do
   local adornment=line.adornment
   adornment:Clear(); adornment.Adornee=nil
   adornment:AddLine(frame.Position,frame:PointToWorldSpace(line.axis*1.5)); adornment.Adornee=part
  end
  if segments then
   limit:Clear(); limit.Adornee=nil
   for _,segment in ipairs(AxisGizmo.toWorldSegments(frame,segments)) do limit:AddLine(segment[1],segment[2]) end
   limit.Adornee=part
  end
  return true
 end
 function api:destroy()
  if dead then return end
  dead=true
  for _,line in ipairs(lines) do line.adornment:Destroy() end
  limit:Destroy()
 end
 return api
end
return AxisGizmo
