--!strict
-- Owns a disposable world-space clone. The caller owns the parent and target UI.
local WorldGhostSession={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function unique(parent,name)
 local found=nil
 for _,child in ipairs(parent:GetChildren()) do
  if child.Name==name then assert(not found,'duplicate name in ghost path: '..name); found=child end
 end
 assert(found,'ghost path missing: '..name)
 return found
end
function WorldGhostSession.new(definition,parent,components)
 assert(typeof(definition)=='Instance' and definition:IsA('Folder') and definition:GetAttribute('SchemaVersion')==1,'select a chain definition')
 assert(typeof(parent)=='Instance','ghost parent required')
 assert(type(components)=='table' and type(components.createChain)=='function','ghost chain factory required')
 local container=definition.Parent
 local source=container and container.Parent
 assert(container and container:IsA('Folder') and container.Name=='EditRigIKChains' and source and source:IsA('Model'),'chain must belong to a model')
 assert(unique(source,container.Name)==container and unique(container,definition.Name)==definition,'ambiguous chain path')
 assert(source.Archivable and #source:GetDescendants()<=5000,'model cannot be cloned or exceeds ghost size limit')
 local iterations=definition:GetAttribute('Iterations')
 assert(finite(iterations) and iterations%1==0 and iterations>=1 and iterations<=1000,'invalid iterations')
 local iterationCap=math.min(iterations,40)
 local clone,chain=nil,nil
 local ok,result=pcall(function()
  clone=source:Clone(); assert(clone,'could not clone model')
  clone.Archivable=false
  local copy=unique(unique(clone,container.Name),definition.Name)
  local refs=unique(copy,'Joints'); assert(refs:IsA('Folder'),'ghost joints missing')
  local ordered=refs:GetChildren(); assert(#ordered>0 and #ordered<=128,'invalid joint count')
  for _,ref in ipairs(ordered) do assert(ref:IsA('ObjectValue') and finite(ref:GetAttribute('Order')),'invalid joint reference') end
  table.sort(ordered,function(a,b) return a:GetAttribute('Order')<b:GetAttribute('Order') end)
  local chainJoints={}
  for i,ref in ipairs(ordered) do
   local joint=ref.Value
   assert(ref:GetAttribute('Order')==i and joint and joint:IsDescendantOf(clone) and (joint:IsA('Motor6D') or joint:IsA('Bone')) and not chainJoints[joint],'invalid ghost joint reference')
   if joint:IsA('Motor6D') then
    assert(joint.Part0 and joint.Part1 and joint.Part0:IsDescendantOf(clone) and joint.Part1:IsDescendantOf(clone),'ghost motor references must belong to clone')
   end
   chainJoints[joint]=true
  end
  local endpointRef=unique(copy,'Endpoint')
  assert(endpointRef:IsA('ObjectValue') and endpointRef.Value and endpointRef.Value.ClassName=='Attachment' and endpointRef.Value:IsDescendantOf(clone),'invalid ghost endpoint')
  local endpoint=endpointRef.Value
  local last=ordered[#ordered].Value
  local adjacency={}
  local function edge(from,to,relative)
   local edges=adjacency[from] or {}; adjacency[from]=edges
   table.insert(edges,{part=to,relative=relative})
  end
  -- Capture rigid branches before removing physics controllers.
  for _,item in ipairs(clone:GetDescendants()) do
   if (item:IsA('JointInstance') or item:IsA('WeldConstraint')) and not chainJoints[item] and item.Enabled then
    local p0,p1=item.Part0,item.Part1
    if p0 and p1 and p0~=p1 and p0:IsDescendantOf(clone) and p1:IsDescendantOf(clone) then
     local relative=p0.CFrame:ToObjectSpace(p1.CFrame)
     edge(p0,p1,relative); edge(p1,p0,relative:Inverse())
    end
   end
  end
  for _,item in ipairs(clone:GetDescendants()) do
   if item:IsA('LuaSourceContainer') or item:IsA('Animator') or item:IsA('IKControl') or item:IsA('AnimationController') or item:IsA('Humanoid') or item:IsA('Constraint') or item:IsA('WeldConstraint') or item:IsA('Explosion') or item:IsA('Sound') or item:IsA('ParticleEmitter') or item:IsA('Trail') or item:IsA('Beam') or item:IsA('Fire') or item:IsA('Smoke') or item:IsA('Sparkles') or item:IsA('ClickDetector') or item:IsA('ProximityPrompt') or item:IsA('DragDetector') or item:IsA('Light') or item:IsA('LayerCollector') or item:IsA('GuiObject') or item:IsA('Highlight') or item:IsA('PVAdornment') then
    item:Destroy()
   elseif item:IsA('JointInstance') and not chainJoints[item] then
    item:Destroy()
   elseif item:IsA('BasePart') then
    item.Anchored=true; item.CanCollide=false; item.CanTouch=false; item.CanQuery=false; item.CastShadow=false
    item.Transparency=math.max(item.Transparency,.55)
   elseif item:IsA('ObjectValue') and item.Value and not item.Value:IsDescendantOf(clone) then
    item.Value=nil
   end
  end
  local partFrames,transforms={},{}
  local function updateParts()
   local visited,queue={},{}
   for _,ref in ipairs(ordered) do
    local joint=ref.Value
    if joint:IsA('Motor6D') then
     assert(joint.Part0 and joint.Part1 and joint.Part0:IsDescendantOf(clone) and joint.Part1:IsDescendantOf(clone),'ghost motor left model')
     visited[joint.Part0]=true; visited[joint.Part1]=true
     joint.Part1.CFrame=joint.Part0.CFrame*joint.C0*joint.Transform*joint.C1:Inverse()
     table.insert(queue,joint.Part1)
    end
   end
   local index=1
   while index<=#queue do
    local part=queue[index]; index+=1
    for _,connection in ipairs(adjacency[part] or {}) do
     if not visited[connection.part] then
      visited[connection.part]=true; connection.part.CFrame=part.CFrame*connection.relative
      table.insert(queue,connection.part)
     end
    end
   end
  end
  local function endPosition()
   return if last:IsA('Bone') then last.TransformedWorldCFrame:PointToWorldSpace(endpoint.Position) else endpoint.WorldPosition
  end
  chain=components.createChain(copy)
  assert(chain and type(chain.solve)=='function' and type(chain.destroy)=='function','invalid ghost chain')
  -- Keep the source's captured pose until the first solve; detached Motor6D
  -- parts can initially differ from their forward-kinematics position.
  for _,item in ipairs(clone:GetDescendants()) do
   if item:IsA('BasePart') then partFrames[item]=item.CFrame
   elseif item:IsA('Motor6D') or item:IsA('Bone') then transforms[item]=item.Transform end
  end
  local start=endPosition()
  clone.Parent=parent -- parent only after removing supported active content
  local dead=false
  local api={}
  function api:isValid()
   return not dead and clone.Parent==parent and endpoint:IsDescendantOf(clone)
  end
  function api:startTarget() assert(self:isValid(),'ghost is closed or missing'); return start end
  function api:solveTarget(target,overrides)
   assert(self:isValid(),'ghost is closed or missing')
   assert(typeof(target)=='Vector3' and finite(target.X) and finite(target.Y) and finite(target.Z),'target must be finite')
   assert(overrides==nil or type(overrides)=='table','solver overrides must be a table')
   local count=iterationCap
   if overrides then
    for key,value in pairs(overrides) do
     assert(key=='iterations','unsupported ghost solver option: '..tostring(key))
     assert(finite(value) and value%1==0 and value>=1 and value<=iterationCap,'invalid ghost iteration count')
     count=value
    end
   end
   local solveOk,solved=pcall(function()
    local value=chain:solve(target,{iterations=count,maxAngularSpeed=0})
    updateParts()
    return value
   end)
   if not solveOk then
    dead=true; pcall(function() chain:destroy() end); chain=nil; clone:Destroy()
    error(solved)
   end
   return solved
  end
  function api:reset()
   assert(self:isValid(),'ghost is closed or missing')
   local resetOk,resetError=pcall(function()
    chain:destroy(); chain=nil
    for part,frame in pairs(partFrames) do part.CFrame=frame end
    for joint,transform in pairs(transforms) do joint.Transform=transform end
    chain=components.createChain(copy)
    assert(chain and type(chain.solve)=='function' and type(chain.destroy)=='function','invalid ghost chain')
   end)
   if not resetOk then
    dead=true; if chain then pcall(function() chain:destroy() end); chain=nil end
    clone:Destroy(); error(resetError)
   end
  end
  function api:destroy()
   if dead then return end
   dead=true
   if chain then pcall(function() chain:destroy() end); chain=nil end
   clone:Destroy()
  end
  return api
 end)
 if not ok then
  if chain then pcall(function() chain:destroy() end) end
  if clone then clone:Destroy() end
  error(result)
 end
 return result
end
return WorldGhostSession
