--!strict
-- The editor creates this disposable clone inside a ViewportFrame for a chain
-- preview. Solves affect the clone, not the source rig; the editor closes the
-- session when the preview or plugin panel closes.
local PreviewSession={}
local function unique(parent,name)
 local found=nil
 for _,child in ipairs(parent:GetChildren()) do
  if child.Name==name then assert(not found,'duplicate name in preview path: '..name); found=child end
 end
 assert(found,'preview path missing: '..name)
 return found
end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function PreviewSession.new(definition,viewport,components)
 assert(typeof(definition)=='Instance' and definition:IsA('Folder') and (definition:GetAttribute('SchemaVersion')==1 or definition:GetAttribute('SchemaVersion')==2 or definition:GetAttribute('SchemaVersion')==3),'select a chain definition')
 assert(typeof(viewport)=='Instance' and viewport:IsA('ViewportFrame') and #viewport:GetChildren()==0 and viewport.CurrentCamera==nil,'empty preview viewport required')
 assert(type(components)=='table' and type(components.createChain)=='function','preview chain factory required')
 local container=definition.Parent
 local source=container and container.Parent
 assert(container and container:IsA('Folder') and container.Name=='EditRigIKChains' and source and source:IsA('Model'),'chain must belong to a model')
 assert(unique(source,container.Name)==container and unique(container,definition.Name)==definition,'ambiguous chain path')
 assert(source.Archivable and #source:GetDescendants()<=5000,'model cannot be cloned or exceeds preview size limit')
 local clone,world,camera,chain=nil,nil,nil,nil
 local ok,result=pcall(function()
  clone=source:Clone(); assert(clone,'could not clone model')
  local copy=unique(unique(clone,container.Name),definition.Name)
  for _,item in ipairs(clone:GetDescendants()) do
   if item:IsA('LuaSourceContainer') or item:IsA('IKControl') or item:IsA('Animator') then item:Destroy()
   elseif item:IsA('BasePart') then item.Anchored=true; item.CanCollide=false end
  end
  local refs=copy:FindFirstChild('Joints'); assert(refs and refs:IsA('Folder'),'preview joints missing')
  local ordered=refs:GetChildren()
  for _,ref in ipairs(ordered) do assert(ref:IsA('ObjectValue') and type(ref:GetAttribute('Order'))=='number','invalid preview joint reference') end
  table.sort(ordered,function(a,b) return a:GetAttribute('Order')<b:GetAttribute('Order') end)
  chain=components.createChain(copy)
  local adjacency,chainJoints={},{}
  for _,ref in ipairs(ordered) do chainJoints[ref.Value]=true end
  local function addEdge(from,to,relative)
   local edges=adjacency[from] or {}; adjacency[from]=edges
   table.insert(edges,{part=to,relative=relative})
  end
  for _,item in ipairs(clone:GetDescendants()) do
   if (item:IsA('JointInstance') or item:IsA('WeldConstraint')) and not chainJoints[item] and item.Enabled then
    local p0,p1=item.Part0,item.Part1
    if p0 and p1 and p0~=p1 and p0:IsDescendantOf(clone) and p1:IsDescendantOf(clone) then
     local relative=p0.CFrame:ToObjectSpace(p1.CFrame)
     addEdge(p0,p1,relative); addEdge(p1,p0,relative:Inverse())
    end
   end
  end
  local function updateParts()
   local visited,queue={},{}
   for _,ref in ipairs(ordered) do
    local joint=ref.Value
    if joint:IsA('Motor6D') then
     visited[joint.Part0]=true; visited[joint.Part1]=true
     joint.Part1.CFrame=joint.Part0.CFrame*joint.C0*joint.Transform*joint.C1:Inverse()
     table.insert(queue,joint.Part1)
    end
   end
   local index=1
   while index<=#queue do
    local part=queue[index]; index+=1
    for _,edge in ipairs(adjacency[part] or {}) do
     if not visited[edge.part] then
      visited[edge.part]=true
      edge.part.CFrame=part.CFrame*edge.relative
      table.insert(queue,edge.part)
     end
    end
   end
  end
  updateParts()
  local endpoint=copy:FindFirstChild('Endpoint').Value
  local last=ordered[#ordered].Value
  local start=if last:IsA('Bone') then last.TransformedWorldCFrame:PointToWorldSpace(endpoint.Position) else endpoint.WorldPosition
  local box,size=clone:GetBoundingBox()
  local extent=math.max(size.X,size.Y,size.Z,1)
  world=Instance.new('WorldModel'); world.Name='EditRigIKPreviewWorld'; world.Parent=viewport
  clone.Parent=world
  local skeleton=Instance.new('Folder'); skeleton.Name='EditRigIKSkeleton'; skeleton.Parent=world
  local links={}
  local thickness=math.clamp(extent*.025,.04,.2)
  for i=1,#ordered do
   local link=Instance.new('Part'); link.Name=string.format('Link%03d',i); link.Anchored=true
   link.CanCollide=false; link.CanTouch=false; link.CanQuery=false; link.CastShadow=false
   link.Material=Enum.Material.Neon; link.Color=Color3.fromRGB(75,205,255); link.Parent=skeleton
   links[i]=link
  end
  local function jointPosition(joint)
   if joint:IsA('Motor6D') then return (joint.Part0.CFrame*joint.C0).Position end
   return joint.TransformedWorldCFrame.Position
  end
  local function endPosition()
   return if last:IsA('Bone') then last.TransformedWorldCFrame:PointToWorldSpace(endpoint.Position) else endpoint.WorldPosition
  end
  local function updateSkeleton()
   for i,ref in ipairs(ordered) do
    local a=jointPosition(ref.Value)
    local b=if ordered[i+1] then jointPosition(ordered[i+1].Value) else endPosition()
    local length=(b-a).Magnitude; local link=links[i]
    if length<1e-6 then link.Transparency=1; link.Size=Vector3.new(thickness,thickness,.001)
    else link.Transparency=0; link.Size=Vector3.new(thickness,thickness,length); link.CFrame=CFrame.lookAt((a+b)*.5,b) end
   end
  end
  updateSkeleton()
  local function marker(name,color,diameter)
   local part=Instance.new('Part'); part.Name=name; part.Shape=Enum.PartType.Ball
   part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false; part.CastShadow=false
   part.Color=color; part.Size=Vector3.one*diameter; part.Position=start; part.Parent=world
   return part
  end
  local markerSize=math.clamp(extent*.035,.12,.6)
  local targetMarker=marker('EditRigIKTargetMarker',Color3.fromRGB(255,80,80),markerSize*1.5)
  local endpointMarker=marker('EditRigIKEndpointMarker',Color3.fromRGB(80,255,120),markerSize)
  camera=Instance.new('Camera'); camera.Name='EditRigIKPreviewCamera'; camera.FieldOfView=45
  local function frameCamera(target)
   local low=box.Position-size*.5; local high=box.Position+size*.5
   local function include(p)
    low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
    high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
   end
   include(target); include(endPosition())
   for _,ref in ipairs(ordered) do include(jointPosition(ref.Value)) end
   local center=(low+high)*.5
   local radius=math.max(1,(high-low).Magnitude*.5)
   camera.CFrame=CFrame.lookAt(center+Vector3.new(1,.7,1).Unit*radius*3.2,center)
  end
  frameCamera(start)
  camera.Parent=viewport; viewport.CurrentCamera=camera
  local dead=false
  local api={}
  function api:solveOffset(offset)
   assert(not dead,'preview is closed')
   assert(typeof(offset)=='Vector3' and finite(offset.X) and finite(offset.Y) and finite(offset.Z),'preview offset must be finite')
   local solved=chain:solve(start+offset,{maxAngularSpeed=0})
   updateParts()
   updateSkeleton()
   targetMarker.Position=start+offset
   endpointMarker.Position=solved.endpointWorld
   frameCamera(targetMarker.Position)
   return solved
  end
  function api:destroy()
   if dead then return end
   dead=true
   pcall(function() chain:destroy() end)
   viewport.CurrentCamera=nil
   world:Destroy(); camera:Destroy()
  end
  return api
 end)
 if not ok then
  if chain then pcall(function() chain:destroy() end) end
  if world then world:Destroy() end
  if clone then clone:Destroy() end
  if camera then camera:Destroy() end
  viewport.CurrentCamera=nil
  error(result)
 end
 return result
end
return PreviewSession
