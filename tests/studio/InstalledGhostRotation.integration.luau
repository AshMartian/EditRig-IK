-- Installed-plugin interactive smoke fixture. Run in Studio Edit while the
-- EditRig IK panel is open and idle, then use the actual UI buttons in order:
-- Start viewport simulation -> Rotate target -> Move target -> End viewport
-- simulation. The fixture checks effects and cleans up on success, failure,
-- selection change, or timeout. It does not simulate a ring drag.
local run=game:GetService('RunService')
local selection=game:GetService('Selection')
local input=game:GetService('UserInputService')
local core=game:GetService('CoreGui')
local gui=game:GetService('PluginGuiService').PluginGui:FindFirstChild('EditRigPanel')
assert(run:IsEdit() and gui and gui.Visible and gui.Parent.Enabled,'open the installed EditRig IK panel in Edit mode')
assert(not input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not input:GetFocusedTextBox(),'finish the current pointer or text edit first')
assert(not workspace:FindFirstChild('EditRigIKGhostSession') and not core:FindFirstChild('EditRigIKGhostGui'),'close the current viewport simulation first')
assert(not workspace:FindFirstChild('EditRigIKRotationSmokeFixture'),'remove the previous smoke fixture first')
local modeButton=gui:FindFirstChild('GhostTargetMode',true)
assert(modeButton and modeButton:IsA('TextButton'),'installed plugin has no target rotation control')
local previous=selection:Get()
local draft={}
for _,item in ipairs(gui:GetDescendants()) do
 if item:IsA('TextBox') then draft[item]=item.Text end
end
local model=Instance.new('Model'); model.Name='EditRigIKRotationSmokeFixture'; model.Archivable=true
local function selectedOnly(object)
 local current=selection:Get()
 return #current==1 and current[1]==object
end
local function object(class,name,parent)
 local value=Instance.new(class); value.Name=name; value.Parent=parent; return value
end
local base=object('Part','Base',model); base.Anchored=true; base.CFrame=CFrame.new(0,-5000,0)
local tip=object('Part','Tip',model); tip.Anchored=true; tip.CFrame=CFrame.new(1,-5000,0)
local joint=object('Motor6D','Root',base); joint.Part0=base; joint.Part1=tip
local endpoint=object('Attachment','Endpoint',tip); endpoint.CFrame=CFrame.new(1,0,0)*CFrame.Angles(.1,.2,.3)
local chains=object('Folder','EditRigIKChains',model)
local definition=object('Folder','RotationSmoke',chains)
definition:SetAttribute('SchemaVersion',1); definition:SetAttribute('Iterations',30); definition:SetAttribute('Tolerance',.01)
local endpointRef=object('ObjectValue','Endpoint',definition); endpointRef.Value=endpoint
local joints=object('Folder','Joints',definition)
local ref=object('ObjectValue','Joint001',joints); ref.Value=joint
ref:SetAttribute('Order',1); ref:SetAttribute('Kind','Ball'); ref:SetAttribute('Axis','Z')
ref:SetAttribute('LowerDegrees',-180); ref:SetAttribute('UpperDegrees',180); ref:SetAttribute('SwingDegrees',180); ref:SetAttribute('Weight',1)
local beforeBase,beforeTip,beforeTransform=base.CFrame,tip.CFrame,joint.Transform
model.Parent=workspace
selection:Set({definition})

task.spawn(function()
 local function waitFor(predicate,description)
  local deadline=os.clock()+120
  while os.clock()<deadline do
   assert(gui.Parent and gui.Visible and gui.Parent.Enabled,'panel was closed')
   assert(selectedOnly(definition),'selection changed; fixture cancelled')
   if predicate() then return end
   task.wait(.1)
  end
  error('timed out waiting for '..description)
 end
 local ok,result=xpcall(function()
  waitFor(function() return workspace:FindFirstChild('EditRigIKGhostSession') and core:FindFirstChild('EditRigIKGhostGui') end,'Start viewport simulation')
  local world=workspace:FindFirstChild('EditRigIKGhostSession')
  local guides=core:FindFirstChild('EditRigIKGhostGui')
  local moves=guides:FindFirstChild('EditRigIKTargetHandles')
  local rings=guides:FindFirstChild('EditRigIKTargetRotationHandles')
  assert(world and moves and rings and moves.Visible and not rings.Visible,'simulation should start with movement handles')
  assert(world:FindFirstChild('EditRigIKRotationSmokeFixture')~=model,'simulation must use a separate clone')
  waitFor(function() return modeButton.Text=='Move target' end,'Rotate target')
  assert(rings.Parent==guides and rings.Visible and not moves.Visible,'rotation rings must replace movement handles')
  assert(rings.Adornee and rings.Adornee.CFrame.Rotation:FuzzyEq(endpoint.WorldCFrame.Rotation,1e-4),'rings start at the endpoint orientation')
  waitFor(function() return modeButton.Text=='Rotate target' end,'Move target')
  assert(moves.Visible and not rings.Visible,'movement handles must return')
  waitFor(function() return not workspace:FindFirstChild('EditRigIKGhostSession') and not core:FindFirstChild('EditRigIKGhostGui') end,'End viewport simulation')
  assert(base.CFrame:FuzzyEq(beforeBase,1e-6) and tip.CFrame:FuzzyEq(beforeTip,1e-6) and joint.Transform:FuzzyEq(beforeTransform,1e-6),'preview must not change source pose')
  return 'Installed ghost target mode buttons, source isolation, and preview cleanup passed; physical ring dragging was not tested.'
 end,debug.traceback)
 -- Selection restoration closes any unfinished preview through PreviewGuard.
 -- If the user selected something else, never override that newer selection.
 if selectedOnly(definition) then
  -- Do not destroy a selected fixture or restore the draft while the user is
  -- actively interacting; wait for idle or a user-driven selection change.
  while selectedOnly(definition) and (input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or input:GetFocusedTextBox()) do task.wait(.1) end
  if selectedOnly(definition) and not input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not input:GetFocusedTextBox() then
   selection:Set(previous); task.wait(.3)
   local current=selection:Get(); local same=#current==#previous
   for i,item in ipairs(previous) do if current[i]~=item then same=false end end
   if same then for field,text in pairs(draft) do if field.Parent then field.Text=text end end end
  end
 end
 model:Destroy()
 if ok then print(result) else warn('Installed ghost rotation smoke failed: '..tostring(result)) end
end)
return 'Rotation smoke fixture armed: Start viewport simulation, Rotate target, Move target, End viewport simulation. Watch Output for the result.'
