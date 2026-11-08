--!strict
-- Owns a disposable world-space clone. The caller owns the parent and target UI.
local WorldGhostSession={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function finiteFrame(frame)
 if typeof(frame)~='CFrame' then return false end
 for _,component in ipairs({frame:GetComponents()}) do if not finite(component) then return false end end
 return true
end
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
 local moveForeign=components.moveForeign or function(child,destination) child.Parent=destination end
 assert(type(moveForeign)=='function','moveForeign must be a function')
 local container=definition.Parent
 local source=container and container.Parent
 assert(container and container:IsA('Folder') and container.Name=='EditRigIKChains' and source and source:IsA('Model'),'chain must belong to a model')
 assert(unique(source,container.Name)==container and unique(container,definition.Name)==definition,'ambiguous chain path')
 assert(source.Archivable and #source:GetDescendants()<=5000,'model cannot be cloned or exceeds ghost size limit')
 local sourceParents={[source]=source.Parent}
 local knownSource={[source]=true}
 for _,item in ipairs(source:GetDescendants()) do sourceParents[item]=item.Parent; knownSource[item]=true end
 local iterations=definition:GetAttribute('Iterations')
 assert(finite(iterations) and iterations%1==0 and iterations>=1 and iterations<=1000,'invalid iterations')
 local iterationCap=math.min(iterations,40)
 local clone,chain,owned,ownedSet=nil,nil,nil,nil
 local function disposeClone()
  if clone and ownedSet then
   -- Preserve foreign objects placed in the ghost while it was open. Source
   -- descendants have a known original parent; other objects go outside the
   -- temporary preview container (or become unparented if no safe parent exists).
   local owners={clone}
   for _,item in ipairs(owned) do table.insert(owners,item) end
   local foreign={}
   for _,owner in ipairs(owners) do
    for _,child in ipairs(owner:GetChildren()) do
     if not ownedSet[child] then table.insert(foreign,child) end
    end
   end
   local function originalDepth(child)
    if not knownSource[child] then return math.huge end
    local depth=0
    while sourceParents[child] and knownSource[sourceParents[child]] do
     child=sourceParents[child]; depth+=1
    end
    return depth
   end
   table.sort(foreign,function(a,b) return originalDepth(a)<originalDepth(b) end)
   for _,child in ipairs(foreign) do
      local external=source.Parent
      if external and (ownedSet[external] or external==parent or external:IsDescendantOf(parent) or external==child or external:IsDescendantOf(child)) then external=nil end
      local destination=sourceParents[child]
      if destination and (ownedSet[destination] or destination==parent or destination:IsDescendantOf(parent) or destination==child or destination:IsDescendantOf(child)) then destination=nil end
      if not destination then destination=external end
      local function moveTo(target)
       local moved=pcall(moveForeign,child,target)
       return moved and child.Parent==target
      end
      local moved=moveTo(destination)
      if not moved and external~=destination then moved=moveTo(external) end
      if not moved then moved=moveTo(nil) end
      assert(moved,'could not preserve an unrelated object inside the ghost')
   end
  end
  if clone then clone:Destroy() end
  -- A user may have reparented a temporary descendant outside the clone.
  -- The captured list contains only instances made by cloning the source.
  if owned then for _,item in ipairs(owned) do item:Destroy() end end
 end
 local ok,result=pcall(function()
  clone=source:Clone(); assert(clone,'could not clone model')
  clone.Archivable=false
  local clonedContainer=unique(clone,container.Name)
  local copy=unique(clonedContainer,definition.Name)
  local refs=unique(copy,'Joints'); assert(refs:IsA('Folder'),'ghost joints missing')
  local ordered=refs:GetChildren(); assert(#ordered>0 and #ordered<=128,'invalid joint count')
  for _,ref in ipairs(ordered) do assert(ref:IsA('ObjectValue') and finite(ref:GetAttribute('Order')),'invalid joint reference') end
  table.sort(ordered,function(a,b) return a:GetAttribute('Order')<b:GetAttribute('Order') end)
  local chainJoints,expectedJoints={},{}
  for i,ref in ipairs(ordered) do
   local joint=ref.Value
   assert(ref:GetAttribute('Order')==i and joint and joint:IsDescendantOf(clone) and (joint:IsA('Motor6D') or joint:IsA('Bone')) and not chainJoints[joint],'invalid ghost joint reference')
   if joint:IsA('Motor6D') then
    assert(joint.Part0 and joint.Part1 and joint.Part0:IsDescendantOf(clone) and joint.Part1:IsDescendantOf(clone),'ghost motor references must belong to clone')
   end
   chainJoints[joint]=true
   expectedJoints[i]={joint=joint,parent=joint.Parent,part0=if joint:IsA('Motor6D') then joint.Part0 else nil,part1=if joint:IsA('Motor6D') then joint.Part1 else nil}
  end
  local endpointRef=unique(copy,'Endpoint')
  assert(endpointRef:IsA('ObjectValue') and endpointRef.Value and endpointRef.Value.ClassName=='Attachment' and endpointRef.Value:IsDescendantOf(clone),'invalid ghost endpoint')
  local endpoint=endpointRef.Value
  local endpointParent=endpoint.Parent
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
  owned=clone:GetDescendants()
  ownedSet={[clone]=true}
  for _,item in ipairs(owned) do ownedSet[item]=true end
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
  local function endFrame()
   return if last:IsA('Bone') then last.TransformedWorldCFrame*endpoint.CFrame else endpoint.WorldCFrame
  end
  chain=components.createChain(copy)
  assert(chain and type(chain.solve)=='function' and type(chain.destroy)=='function','invalid ghost chain')
  -- Keep the source's captured pose until the first solve; detached Motor6D
  -- parts can initially differ from their forward-kinematics position.
  for _,item in ipairs(clone:GetDescendants()) do
   if item:IsA('BasePart') then partFrames[item]=item.CFrame
   elseif item:IsA('Motor6D') or item:IsA('Bone') then transforms[item]=item.Transform end
  end
  local capturedFrame=endFrame()
  local start=capturedFrame.Position
  local orientation=capturedFrame.Rotation
  clone.Parent=parent -- parent only after removing supported active content
  local dead,closing=false,false
  local function cleanup()
   closing=true
   if chain then pcall(function() chain:destroy() end); chain=nil end
   disposeClone()
   dead=true
  end
  local api={}
  function api:isValid()
   if dead or closing or clone.Parent~=parent or clonedContainer.Parent~=clone or copy.Parent~=clonedContainer or refs.Parent~=copy or #refs:GetChildren()~=#ordered or endpointRef.Parent~=copy or endpointRef.Value~=endpoint or endpoint.Parent~=endpointParent or not endpoint:IsDescendantOf(clone) then return false end
   for i,ref in ipairs(ordered) do
    local entry=expectedJoints[i]
    local joint=entry.joint
    if ref.Parent~=refs or ref.Value~=joint or ref:GetAttribute('Order')~=i or joint.Parent~=entry.parent or not joint:IsDescendantOf(clone) then return false end
    if joint:IsA('Motor6D') and (joint.Part0~=entry.part0 or joint.Part1~=entry.part1 or not joint.Enabled or not entry.part0:IsDescendantOf(clone) or not entry.part1:IsDescendantOf(clone)) then return false end
   end
   return true
  end
  function api:startTarget() assert(self:isValid(),'ghost is closed or missing'); return start end
  function api:startOrientation() assert(self:isValid(),'ghost is closed or missing'); return orientation end
  function api:solveTarget(target,overrides)
   assert(self:isValid(),'ghost is closed or missing')
   assert(typeof(target)=='Vector3' and finite(target.X) and finite(target.Y) and finite(target.Z),'target must be finite')
   assert(overrides==nil or type(overrides)=='table','solver overrides must be a table')
   local count=iterationCap
   local targetOrientation,orientationTolerance=nil,nil
   if overrides then
    for key,value in pairs(overrides) do
     if key=='iterations' then
      assert(finite(value) and value%1==0 and value>=1 and value<=iterationCap,'invalid ghost iteration count')
      count=value
     elseif key=='targetOrientation' then
      assert(finiteFrame(value),'target orientation must be a finite CFrame')
      targetOrientation=value.Rotation
     elseif key=='orientationTolerance' then
      assert(finite(value) and value>=0 and value<=math.pi,'orientation tolerance must be between 0 and pi radians')
      orientationTolerance=value
     else
      error('unsupported ghost solver option: '..tostring(key))
     end
    end
   end
   local solveOk,solved=pcall(function()
    local value=chain:solve(target,{iterations=count,maxAngularSpeed=0,targetOrientation=targetOrientation,orientationTolerance=orientationTolerance})
    updateParts()
    return value
   end)
   if not solveOk then
    local cleaned,cleanupError=pcall(cleanup)
    if not cleaned then error(tostring(solved)..'; preview cleanup failed: '..tostring(cleanupError)) end
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
    local cleaned,cleanupError=pcall(cleanup)
    if not cleaned then error(tostring(resetError)..'; preview cleanup failed: '..tostring(cleanupError)) end
    error(resetError)
   end
  end
  function api:destroy()
   if dead then return end
   cleanup()
  end
  return api
 end)
 if not ok then
  if chain then pcall(function() chain:destroy() end) end
  disposeClone()
  error(result)
 end
 return result
end
return WorldGhostSession
