--!strict
-- Editor.server.luau owns this overlay while the panel is open. It renders
-- temporary joint markers and lines outside the rig and reports marker clicks;
-- the editor calls destroy when the overlay is hidden or no longer valid.
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
function RigOverlay.new(rig,holder,onSelect,inference)
 assert(typeof(rig)=='Instance' and rig:IsA('Model') and rig:IsDescendantOf(workspace),'select a model in Workspace')
 assert(typeof(holder)=='Instance' and type(onSelect)=='function','overlay holder and selection callback required')
 local joints={}
 for _,item in ipairs(rig:GetDescendants()) do
  if item:IsA('Motor6D') or item:IsA('Bone') then table.insert(joints,item) end
 end
 assert(#joints>0 and #joints<=300,'model must have 1 to 300 joints')
 local entries,motorByPart,entryJoints={},{},{}
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
  entryJoints[joint]=true
 end
 local selectedOutline=Instance.new('WireframeHandleAdornment'); selectedOutline.Name='EditRigIKSelectedOutline'
 selectedOutline.Color3=Color3.fromRGB(255,245,205); selectedOutline.Thickness=2
 selectedOutline.AlwaysOnTop=true; selectedOutline.ZIndex=6; selectedOutline.Parent=holder
 local dead=false
 local dirty=true
 local cachedSelection=nil
 local chainState=nil
 local active=nil
 local optionRoot,optionEndpoint,optionEndJoint=nil,nil,nil
 local optionsChanged=false
 local endpointNameWatcher=nil
 local graphLimited=false
 local propertyWatchers={}
 local graphWatchers={
  rig.DescendantAdded:Connect(function() dirty=true end),
  rig.DescendantRemoving:Connect(function() dirty=true end),
 }
 local function refreshGraph()
  for _,connection in ipairs(propertyWatchers) do connection:Disconnect() end
  propertyWatchers={}; motorByPart={}; graphLimited=false
  local descendants=rig:GetDescendants()
  if #descendants>5000 then graphLimited=true; return end
  local jointCount=0
  for _,item in ipairs(descendants) do
   if item:IsA('Motor6D') or item:IsA('Bone') then
    jointCount+=1
    if jointCount>300 then graphLimited=true; motorByPart={}; break end
    for _,property in ipairs({'Name','Parent'}) do
     table.insert(propertyWatchers,item:GetPropertyChangedSignal(property):Connect(function() dirty=true end))
    end
   end
   if item:IsA('Motor6D') then
    if item.Part1 then
     if motorByPart[item.Part1]==nil then motorByPart[item.Part1]=item else motorByPart[item.Part1]=false end
    end
    for _,property in ipairs({'Part0','Part1','Enabled'}) do
     table.insert(propertyWatchers,item:GetPropertyChangedSignal(property):Connect(function() dirty=true end))
    end
   end
  end
 end
 local function updateChain(selected)
  if not dirty and not optionsChanged and selected==cachedSelection then return end
  if dirty then refreshGraph() end
  if endpointNameWatcher then endpointNameWatcher:Disconnect(); endpointNameWatcher=nil end
  dirty=false; optionsChanged=false; cachedSelection=selected; chainState=nil; active=nil
  if not selected or not inference then return end
  if not entryJoints[selected] then
   if typeof(selected)=='Instance' and (selected:IsA('Motor6D') or selected:IsA('Bone')) and selected:IsDescendantOf(rig) then
    chainState={ok=false,reason='overlay_stale',message='Rig changed; reopen the joint overlay.'}
   end
   return
  end
  if graphLimited then
   chainState={ok=false,reason='too_complex',message='Rig exceeds the joint overlay size limit.'}; return
  end
  if optionEndJoint~=nil then
   if typeof(optionEndJoint)~='Instance' or not (optionEndJoint:IsA('Motor6D') or optionEndJoint:IsA('Bone')) or optionEndJoint.ClassName~=selected.ClassName or not optionEndJoint:IsDescendantOf(rig) then
    chainState={ok=false,reason='invalid_end_joint',message='The explicit end joint must be a joint of the same type in the rig.'}; return
   end
   if optionEndpoint==nil then
    chainState={ok=false,reason='missing_explicit_endpoint',message='Select an endpoint attachment for the explicit end joint.'}; return
   end
  end
  local ok,result=pcall(inference.infer,rig,selected,{root=optionRoot,endpoint=optionEndpoint})
  if not ok or type(result)~='table' then
   chainState={ok=false,reason='inference_error',message='Could not infer a chain.'}; return
  end
  chainState=result
  if not result.ok then return end
  if optionEndJoint~=nil and result.endJoint~=optionEndJoint then
   chainState={ok=false,reason='explicit_end_mismatch',message='The endpoint does not belong to the selected end joint.'}; return
  end
  local members={}
  for _,joint in ipairs(result.joints) do
   if not entryJoints[joint] then
    chainState={ok=false,reason='overlay_stale',message='Rig changed; reopen the joint overlay.'}; return
   end
   members[joint]=true
  end
  if not members[selected] then
   chainState={ok=false,reason='invalid_chain',message='Inferred chain does not include the selected joint.'}; return
  end
  endpointNameWatcher=result.endpoint:GetPropertyChangedSignal('Name'):Connect(function() dirty=true end)
  active=members
 end
 local api={}
 function api:count() return #entries end
 function api:chainState() return chainState end
 function api:setChainOptions(root,endpoint,endJoint)
  if root~=optionRoot or endpoint~=optionEndpoint or endJoint~=optionEndJoint then
   optionRoot=root; optionEndpoint=endpoint; optionEndJoint=endJoint; optionsChanged=true
  end
 end
 function api:update(selected)
  assert(not dead,'overlay is destroyed')
  updateChain(selected)
  local camera=workspace.CurrentCamera
  selectedOutline:Clear(); selectedOutline.Adornee=nil
  for _,entry in ipairs(entries) do
   local joint=entry.joint
   local part,position=anchorAndPosition(joint,rig)
   local marker,line=entry.marker,entry.line
   marker.Adornee=part
   marker.Transparency=if active and not active[joint] then .7 else 0
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
   line.Transparency=if active and (not active[joint] or not active[parentJoint]) then .7 else 0
   if part and parentPosition and parentJoint~=joint then
    -- In Studio these wireframe points render in world coordinates, unlike
    -- the sphere marker's part-relative CFrame.
    line:AddLine(position,parentPosition); line.Adornee=part
   end
  end
 end
 function api:destroy()
  if dead then return end; dead=true
  if endpointNameWatcher then endpointNameWatcher:Disconnect(); endpointNameWatcher=nil end
  for _,connection in ipairs(graphWatchers) do connection:Disconnect() end
  for _,connection in ipairs(propertyWatchers) do connection:Disconnect() end
  for _,entry in ipairs(entries) do entry.connection:Disconnect(); entry.marker:Destroy(); entry.line:Destroy() end
  selectedOutline:Destroy()
 end
 return api
end
return RigOverlay
