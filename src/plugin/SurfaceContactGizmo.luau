--!strict
-- Disposable world-space contact guide. It does not perform probes or own a rig.
local SurfaceContactGizmo={}

local function finiteVector(value)
 return typeof(value)=='Vector3'
  and value.X==value.X and value.Y==value.Y and value.Z==value.Z
  and math.abs(value.X)<math.huge and math.abs(value.Y)<math.huge and math.abs(value.Z)<math.huge
end

function SurfaceContactGizmo.new(parent)
 assert(typeof(parent)=='Instance', 'contact gizmo parent must be an Instance')
 local folder=Instance.new('Folder')
 folder.Name='EditRigIKSurfaceContact'
 folder.Archivable=false
 local function makePart(name,size,shape,color)
  local part=Instance.new('Part')
  part.Name=name
  part.Anchored=true
  part.CanCollide=false
  part.CanTouch=false
  part.CanQuery=false
  part.Archivable=false
  part.Material=Enum.Material.Neon
  part.Transparency=1
  part.Size=size
  part.Shape=shape
  part.Color=color
  part.Parent=folder
  return part
 end
 local marker=makePart('Contact',Vector3.new(.18,.18,.18),Enum.PartType.Ball,Color3.fromRGB(255,193,64))
 local normal=makePart('Normal',Vector3.new(.035,.035,.8),Enum.PartType.Block,Color3.fromRGB(90,232,255))
 local tip=makePart('NormalTip',Vector3.new(.11,.11,.11),Enum.PartType.Ball,Color3.fromRGB(90,232,255))
 folder.Parent=parent
 local dead=false
 local api={}
 function api:isValid()
  return not dead and folder.Parent==parent and marker.Parent==folder and normal.Parent==folder and tip.Parent==folder
 end
 function api:update(contact)
  assert(self:isValid(), 'surface contact gizmo is destroyed or incomplete')
  local position=if type(contact)=='table' then contact.position else nil
  local direction=if type(contact)=='table' then contact.normal else nil
  local visible=type(contact)=='table' and contact.status=='contact' and finiteVector(position) and finiteVector(direction)
  if visible then
   local magnitude=direction.Magnitude
   visible=magnitude==magnitude and magnitude>1e-8 and magnitude<math.huge
   if visible then
    direction=direction/magnitude
    -- Choose a nonparallel up vector to avoid lookAt degeneracy on horizontal ground.
    local up=if math.abs(direction:Dot(Vector3.yAxis))>.9 then Vector3.xAxis else Vector3.yAxis
    marker.Position=position
    normal.CFrame=CFrame.lookAt(position+direction*(normal.Size.Z/2),position+direction*(normal.Size.Z/2+1),up)
    tip.Position=position+direction*normal.Size.Z
   end
  end
  marker.Transparency=if visible then 0 else 1
  normal.Transparency=if visible then 0 else 1
  tip.Transparency=if visible then 0 else 1
 end
 function api:destroy()
  if dead then return end
  dead=true
  -- Individual children may have been removed or reparented externally.
  marker:Destroy(); normal:Destroy(); tip:Destroy(); folder:Destroy()
 end
 return api
end
return SurfaceContactGizmo
