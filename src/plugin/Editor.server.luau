--!strict
-- Authoring prototype: stores metadata and definitions without starting IK.
local Selection = game:GetService('Selection')
local ChangeHistoryService = game:GetService('ChangeHistoryService')
local RunService = game:GetService('RunService')
local Config = require(script.Config)
local Builder = require(script.DefinitionBuilder).new(Config)
local ChainBuilder = require(script.ChainBuilder).new(Config)
local RigInspector = require(script.RigInspector)
local AxisGizmo = require(script.AxisGizmo)
local toolbar = plugin:CreateToolbar('EditRig IK')
local button = toolbar:CreateButton('Joint Limits', 'Edit IK limit metadata', '')
local widget = plugin:CreateDockWidgetPluginGui('EditRigIKAuthoringV2', DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 460, 650, 320, 420))
widget.Title = 'EditRig IK — prototype'
local root = Instance.new('ScrollingFrame')
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.new()
root.ScrollBarThickness = 6
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(37, 39, 45)
root.Parent = widget
local layout = Instance.new('UIListLayout')
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root
local padding = Instance.new('UIPadding')
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = root
local nextOrder=0
local function order(item: GuiObject)
    nextOrder+=1
    item.LayoutOrder=nextOrder
end
local function label(text: string, height: number): TextLabel
    local item = Instance.new('TextLabel')
    item.Size = UDim2.new(1, 0, 0, height)
    item.BackgroundTransparency = 1
    item.TextColor3 = Color3.fromRGB(235, 235, 240)
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextWrapped = true
    item.Font = Enum.Font.SourceSans
    item.TextSize = 16
    item.Text = text
    order(item)
    item.Parent = root
    return item
end
local selectedLabel = label('Select one Motor6D or Bone in Explorer.', 38)
local notice = label('Prototype: saves settings and idle definitions. No animation starts automatically.', 42)
notice.TextColor3 = Color3.fromRGB(255, 204, 111)
local inspect=Instance.new('TextButton')
inspect.Size=UDim2.new(1,0,0,32); inspect.BackgroundColor3=Color3.fromRGB(61,109,172)
inspect.TextColor3=Color3.new(1,1,1); inspect.Text='Inspect selected model'; inspect.Font=Enum.Font.SourceSansBold; inspect.TextSize=16
order(inspect); inspect.Parent=root
local inspection=label('Select a model and inspect it for existing animation controllers.',40)
inspection.AutomaticSize=Enum.AutomaticSize.Y
inspection.Size=UDim2.new(1,0,0,40)
inspection.TextYAlignment=Enum.TextYAlignment.Top
inspect.MouseButton1Click:Connect(function()
    local items=Selection:Get()
    local model=if #items==1 then items[1] else nil
    if not model or not model:IsA('Model') then inspection.Text='Select exactly one model in Explorer to inspect.'; return end
    local ok,result=pcall(RigInspector.inspect,model)
    inspection.Text=if ok then RigInspector.format(result) else 'Inspection failed: '..tostring(result)
end)
local fields: {[string]: TextBox} = {}
for _, entry in ipairs({{'kind','Limit type'}, {'axis','Local axis'}, {'lower','Lower angle (degrees)'}, {'upper','Upper angle (degrees)'}, {'swing','Ball swing (degrees)'}, {'control','Control name (hinge)'}, {'impulse','Impulse name (hinge)'}, {'frequency','Impulse damping (1/s)'}}) do
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    order(row)
    row.Parent = root
    local caption = Instance.new('TextLabel')
    caption.Size = UDim2.new(0.53, -4, 1, 0)
    caption.BackgroundTransparency = 1
    caption.Text = entry[2]
    caption.TextColor3 = Color3.fromRGB(235,235,240)
    caption.TextXAlignment = Enum.TextXAlignment.Left
    caption.Font = Enum.Font.SourceSans
    caption.TextSize = 16
    caption.Parent = row
    local box = Instance.new('TextBox')
    box.Position = UDim2.new(0.53, 0, 0, 0)
    box.Size = UDim2.new(0.47, 0, 1, 0)
    box.BackgroundColor3 = Color3.fromRGB(60, 63, 72)
    box.TextColor3 = Color3.fromRGB(245, 245, 245)
    box.Text = ''
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.SourceSans
    box.TextSize = 16
    box.Parent = row
    fields[entry[1]] = box
end
local apply = Instance.new('TextButton')
apply.Size = UDim2.new(1, 0, 0, 32)
apply.BackgroundColor3 = Color3.fromRGB(61, 109, 172)
apply.TextColor3 = Color3.new(1,1,1)
apply.Text = 'Save limit metadata'
apply.Font = Enum.Font.SourceSansBold
apply.TextSize = 16
order(apply)
apply.Parent = root
local createActor = Instance.new('TextButton')
createActor.Size = UDim2.new(1, 0, 0, 32)
createActor.BackgroundColor3 = Color3.fromRGB(61, 109, 172)
createActor.TextColor3 = Color3.new(1,1,1)
createActor.Text = 'Create direct-control actor from selected model'
createActor.Font = Enum.Font.SourceSansBold
createActor.TextSize = 15
createActor.TextWrapped = true
order(createActor)
createActor.Parent = root
local status = label('', 65)
local current: Instance? = nil
local axisButton=Instance.new('TextButton')
axisButton.Size=UDim2.new(1,0,0,32); axisButton.BackgroundColor3=Color3.fromRGB(61,109,172)
axisButton.TextColor3=Color3.new(1,1,1); axisButton.Text='Show selected joint rest axes'
axisButton.Font=Enum.Font.SourceSansBold; axisButton.TextSize=16; order(axisButton); axisButton.Parent=root
local axisFolder: Folder?=nil
local axisGizmo: any=nil
local function hideAxes()
    if axisGizmo then axisGizmo:destroy(); axisGizmo=nil end
    if axisFolder then axisFolder:Destroy(); axisFolder=nil end
    axisButton.Text='Show selected joint rest axes'
end
axisButton.MouseButton1Click:Connect(function()
    if axisGizmo then hideAxes(); return end
    if not current then status.Text='Select a Motor6D or Bone first.'; return end
    local folder=Instance.new('Folder'); folder.Name='EditRigIKAxisPreview'
    local ok,result=pcall(function()
        folder.Parent=game:GetService('CoreGui')
        return AxisGizmo.new(folder)
    end)
    if not ok then folder:Destroy(); status.Text='Cannot show axes: '..tostring(result); return end
    axisFolder=folder; axisGizmo=result
    local updated,visible=pcall(function() return axisGizmo:update(current) end)
    if not updated or not visible then hideAxes(); status.Text='Cannot display this joint frame.'; return end
    axisButton.Text='Hide joint rest axes'
    status.Text='Rest axes: X red, Y green, Z blue. These do not display angle limits.'
end)
local axisUpdate=RunService.Heartbeat:Connect(function()
    if axisGizmo then
        local ok=pcall(function() axisGizmo:update(current) end)
        if not ok then hideAxes() end
    end
end)
plugin.Unloading:Connect(function() axisUpdate:Disconnect(); hideAxes() end)
local attrs = {kind='EditRigIK_Kind', axis='EditRigIK_Axis', lower='EditRigIK_LowerDegrees', upper='EditRigIK_UpperDegrees', swing='EditRigIK_SwingDegrees'}
local defaults = {kind='Hinge', axis='X', lower=-90, upper=90, swing=90}
local driveAttrs = {control='EditRigIK_Control',impulse='EditRigIK_Impulse',frequency='EditRigIK_Frequency'}
local function refresh()
    local items = Selection:Get()
    local item = if #items == 1 then items[1] else nil
    if item and (item:IsA('Motor6D') or item:IsA('Bone')) then
        current = item
        selectedLabel.Text = item.ClassName .. ': ' .. item:GetFullName()
        for key, box in pairs(fields) do
            local value = item:GetAttribute(attrs[key] or driveAttrs[key])
            local fallback = defaults[key] or (if key=='control' then item.Name elseif key=='impulse' then item.Name..'Impulse' else 4)
            box.Text = tostring(if value ~= nil then value else fallback)
        end
        status.Text = ''
    else
        current = nil
        selectedLabel.Text = 'Select exactly one Motor6D or Bone in Explorer.'
        status.Text = ''
    end
end
button.Click:Connect(function() widget.Enabled = not widget.Enabled; button:SetActive(widget.Enabled); if widget.Enabled then refresh() end end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function() button:SetActive(widget.Enabled); if not widget.Enabled then hideAxes() end end)
Selection.SelectionChanged:Connect(refresh)
apply.MouseButton1Click:Connect(function()
    local item = current
    if not item or not item.Parent then status.Text = 'Select a valid joint first.'; return end
    local ok, result = pcall(Config.validate, {kind=fields.kind.Text, axis=string.upper(fields.axis.Text), lower=tonumber(fields.lower.Text), upper=tonumber(fields.upper.Text), swing=tonumber(fields.swing.Text)})
    if not ok then status.Text = 'Invalid settings: ' .. tostring(result); return end
    local frequency=tonumber(fields.frequency.Text)
    if not frequency then status.Text='Enter a damping frequency.'; return end
    local driveOk,drive=pcall(Config.validateDrive,{control=fields.control.Text,impulse=fields.impulse.Text,frequency=frequency},item.Name)
    if not driveOk then status.Text='Invalid control settings: '..tostring(drive); return end
    ChangeHistoryService:SetWaypoint('Before EditRig IK limit metadata')
    for key, name in pairs(attrs) do item:SetAttribute(name, result[key]) end
    for key, name in pairs(driveAttrs) do item:SetAttribute(name, drive[key]) end
    item:SetAttribute('EditRigIK_SchemaVersion', 1)
    ChangeHistoryService:SetWaypoint('Save EditRig IK limit metadata')
    status.Text = 'Saved to ' .. item.Name .. '. Recreate the actor definition to include changes.'
end)

createActor.MouseButton1Click:Connect(function()
    local selection=Selection:Get()
    local model=if #selection==1 then selection[1] else nil
    if not model or not model:IsA('Model') then status.Text='Select one model in Explorer to create an actor.'; return end
    local existingController=model:FindFirstChild('EditRigIKController')
    if model:FindFirstChild('EditRigIKActor') then status.Text='Actor already exists; remove or rename it before creating another.'; return end
    if existingController and (not existingController:IsA('ModuleScript') or existingController:GetAttribute('EditRigIK_GeneratedControllerVersion')~=1) then
        status.Text='An incompatible controller already exists; rename it before creating an actor.'; return
    end
    local ok,definition=pcall(Builder.create,model)
    if not ok then status.Text='Cannot create actor: '..tostring(definition); return end
    local controller=if existingController then nil else script.GeneratedController:Clone()
    if controller then controller.Name='EditRigIKController'; controller:SetAttribute('EditRigIK_GeneratedControllerVersion',1) end
    ChangeHistoryService:SetWaypoint('Before create EditRig IK actor')
    definition.Parent=model
    if controller then controller.Parent=model end
    ChangeHistoryService:SetWaypoint('Create EditRig IK actor')
    status.Text='Created idle direct-control actor. Install the runtime and start it explicitly from a script.'
end)

-- Select each item in Explorer, then capture it explicitly so selection order
-- never decides chain direction.
local chainTitle=label('IK chain: capture root joint, end joint, then endpoint attachment.',42)
local chainName=Instance.new('TextBox')
chainName.Size=UDim2.new(1,0,0,28)
chainName.BackgroundColor3=Color3.fromRGB(60,63,72)
chainName.TextColor3=Color3.new(1,1,1)
chainName.PlaceholderText='Chain name'; chainName.Text='Leg'; chainName.ClearTextOnFocus=false
chainName.Font=Enum.Font.SourceSans; chainName.TextSize=16; order(chainName); chainName.Parent=root
local function chainNumberField(labelText: string, default: string): TextBox
    label(labelText,20)
    local box=Instance.new('TextBox')
    box.Size=UDim2.new(1,0,0,28); box.BackgroundColor3=Color3.fromRGB(60,63,72)
    box.TextColor3=Color3.new(1,1,1); box.Text=default; box.ClearTextOnFocus=false
    box.Font=Enum.Font.SourceSans; box.TextSize=16; order(box); box.Parent=root
    return box
end
local iterationsField=chainNumberField('Maximum CCD iterations','30')
local toleranceField=chainNumberField('Target tolerance (studs)','0.01')
local maxStepField=chainNumberField('Maximum correction per iteration (degrees)','180')
local chainStatus=label('No chain selections yet.',55)
local chainFeedback: TextLabel
local firstJoint: Instance?=nil
local lastJoint: Instance?=nil
local endpoint: Instance?=nil
local function refreshChainStatus()
    chainStatus.Text='Root: '..(if firstJoint then firstJoint.Name else '—')..'  |  End: '..(if lastJoint then lastJoint.Name else '—')..'  |  Endpoint: '..(if endpoint then endpoint.Name else '—')
end
local function chainButton(text: string): TextButton
    local item=Instance.new('TextButton')
    item.Size=UDim2.new(1,0,0,30); item.BackgroundColor3=Color3.fromRGB(61,109,172)
    item.TextColor3=Color3.new(1,1,1); item.Text=text; item.Font=Enum.Font.SourceSansBold; item.TextSize=15
    order(item); item.Parent=root
    return item
end
local function selectedOne(): Instance?
    local items=Selection:Get()
    return if #items==1 then items[1] else nil
end
local loadedChain: Instance?=nil
chainButton('Load selected chain settings').MouseButton1Click:Connect(function()
    local definition=selectedOne()
    local ok,settings=pcall(ChainBuilder.readSettings,definition)
    if not ok then loadedChain=nil; chainFeedback.Text='Cannot load chain: '..tostring(settings); return end
    loadedChain=definition
    iterationsField.Text=tostring(settings.iterations)
    toleranceField.Text=tostring(settings.tolerance)
    maxStepField.Text=tostring(settings.maxStepDegrees)
    chainFeedback.Text='Loaded '..definition:GetFullName()..'. Keep it selected to save changes.'
end)
chainButton('Save settings to selected chain').MouseButton1Click:Connect(function()
    local definition=selectedOne()
    if not loadedChain or definition~=loadedChain then chainFeedback.Text='Select the loaded chain and load its settings before saving.'; return end
    local options={iterations=tonumber(iterationsField.Text),tolerance=tonumber(toleranceField.Text),maxStepDegrees=tonumber(maxStepField.Text)}
    if not options.maxStepDegrees then chainFeedback.Text='Enter a maximum correction angle in degrees.'; return end
    local ok,settings=pcall(ChainBuilder.validateSettings,options)
    if not ok then chainFeedback.Text='Invalid settings: '..tostring(settings); return end
    local valid,err=pcall(ChainBuilder.readSettings,definition)
    if not valid then chainFeedback.Text='Cannot save chain: '..tostring(err); return end
    ChangeHistoryService:SetWaypoint('Before edit EditRig IK chain settings')
    ChainBuilder.writeSettings(definition,settings)
    ChangeHistoryService:SetWaypoint('Edit EditRig IK chain settings')
    chainFeedback.Text='Saved '..definition.Name..'. Reopen any active runtime chain to use these settings.'
end)
chainButton('Refresh selected chain limits from joints').MouseButton1Click:Connect(function()
    local definition=selectedOne()
    local valid,err=pcall(ChainBuilder.prepareLimitRefresh,definition)
    if not valid then chainFeedback.Text='Cannot refresh limits: '..tostring(err); return end
    ChangeHistoryService:SetWaypoint('Before refresh EditRig IK chain limits')
    ChainBuilder.refreshLimits(definition)
    ChangeHistoryService:SetWaypoint('Refresh EditRig IK chain limits')
    chainFeedback.Text='Refreshed '..definition.Name..'. Reopen any active runtime chain to use these limits.'
end)
chainButton('Set root joint from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or not (item:IsA('Motor6D') or item:IsA('Bone')) then chainFeedback.Text='Select one Motor6D or Bone as the root.'; return end
    firstJoint=item; refreshChainStatus()
end)
chainButton('Set end joint from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or not (item:IsA('Motor6D') or item:IsA('Bone')) then chainFeedback.Text='Select one Motor6D or Bone as the end.'; return end
    lastJoint=item; refreshChainStatus()
end)
chainButton('Set endpoint attachment from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or item.ClassName~='Attachment' then chainFeedback.Text='Select one regular Attachment as the endpoint.'; return end
    endpoint=item; refreshChainStatus()
end)
chainButton('Create idle IK chain definition').MouseButton1Click:Connect(function()
    local first,last,tip=firstJoint,lastJoint,endpoint
    if not first or not last or not tip then chainFeedback.Text='Capture the root, end and endpoint first.'; return end
    local ancestor=first.Parent
    local model=nil
    while ancestor do
        if ancestor:IsA('Model') and last:IsDescendantOf(ancestor) and tip:IsDescendantOf(ancestor) then model=ancestor; break end
        ancestor=ancestor.Parent
    end
    if not model then chainFeedback.Text='Selections must share a model.'; return end
    local container=model:FindFirstChild('EditRigIKChains')
    if container and not container:IsA('Folder') then chainFeedback.Text='EditRigIKChains exists but is not a folder.'; return end
    if container and container:FindFirstChild(chainName.Text) then chainFeedback.Text='That chain name already exists.'; return end
    local existingController=model:FindFirstChild('EditRigIKController')
    if existingController and (not existingController:IsA('ModuleScript') or existingController:GetAttribute('EditRigIK_GeneratedControllerVersion')~=1) then chainFeedback.Text='An incompatible controller exists; rename it before creating the chain.'; return end
    local maxStep=tonumber(maxStepField.Text)
    if not maxStep then chainFeedback.Text='Enter a maximum correction angle in degrees.'; return end
    local options={iterations=tonumber(iterationsField.Text),tolerance=tonumber(toleranceField.Text),maxStepDegrees=maxStep}
    local ok,definition=pcall(ChainBuilder.create,model,first,last,tip,chainName.Text,options)
    if not ok then chainFeedback.Text='Cannot create chain: '..tostring(definition); return end
    ChangeHistoryService:SetWaypoint('Before create EditRig IK chain')
    if not container then container=Instance.new('Folder'); container.Name='EditRigIKChains'; container.Parent=model end
    definition.Parent=container
    if not existingController then
        local controller=script.GeneratedController:Clone(); controller.Name='EditRigIKController'; controller:SetAttribute('EditRigIK_GeneratedControllerVersion',1); controller.Parent=model
    end
    ChangeHistoryService:SetWaypoint('Create EditRig IK chain')
    chainFeedback.Text='Created idle chain. Use the runtime API to start it after resolving joint ownership.'
end)

chainFeedback=label('',65)
