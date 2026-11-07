--!strict
-- A disposable clone is rendered inside a plugin-owned ViewportFrame.
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
 assert(typeof(definition)=='Instance' and definition:IsA('Folder') and definition:GetAttribute('SchemaVersion')==1,'select a chain definition')
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
  camera=Instance.new('Camera'); camera.Name='EditRigIKPreviewCamera'; camera.FieldOfView=45
  camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(1,.7,1).Unit*extent*2.2,box.Position)
  camera.Parent=viewport; viewport.CurrentCamera=camera
  local dead=false
  local api={}
  function api:solveOffset(offset)
   assert(not dead,'preview is closed')
   assert(typeof(offset)=='Vector3' and finite(offset.X) and finite(offset.Y) and finite(offset.Z),'preview offset must be finite')
   local solved=chain:solve(start+offset)
   updateParts()
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
