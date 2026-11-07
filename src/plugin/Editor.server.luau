--!strict
-- Authoring prototype: stores metadata and definitions without starting IK.
local Selection = game:GetService('Selection')
local ChangeHistoryService = game:GetService('ChangeHistoryService')
local RunService = game:GetService('RunService')
local Config = require(script.Config)
local Builder = require(script.DefinitionBuilder).new(Config)
local ChainBuilder = require(script.ChainBuilder).new(Config)
local ChainDiscovery = require(script.ChainDiscovery)
local RigInspector = require(script.RigInspector)
local AxisGizmo = require(script.AxisGizmo)
local LimitGeometry = require(script.LimitGeometry).new(Config)
local RuntimeInstaller = require(script.RuntimeInstaller)
local InputProfileBuilder = require(script.InputProfileBuilder)
local GaitExampleInstaller = require(script.GaitExampleInstaller)
local JointBatch = require(script.JointBatch)
local toolbar = plugin:CreateToolbar('EditRig IK')
local button = toolbar:CreateButton('Joint Limits', 'Edit IK limit metadata', '')
local widget = plugin:CreateDockWidgetPluginGui('EditRigIKAuthoringV2', DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 460, 650, 320, 420))
widget.Title = 'EditRig IK — prototype'
local root = Instance.new('ScrollingFrame')
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.new()
root.ScrollBarThickness = 6
-- Keep section navigation and command feedback visible while scrolling.
root.Position = UDim2.fromOffset(0, 32)
root.Size = UDim2.new(1, 0, 1, -104)
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
local install=Instance.new('TextButton')
install.Size=UDim2.new(1,0,0,32); install.BackgroundColor3=Color3.fromRGB(61,109,172)
install.TextColor3=Color3.new(1,1,1); install.Text='Install runtime in ReplicatedStorage'; install.Font=Enum.Font.SourceSansBold; install.TextSize=16
order(install); install.Parent=root
local installStatus=label('',42)
install.MouseButton1Click:Connect(function()
    local storage=game:GetService('ReplicatedStorage')
    local ok,copy=pcall(RuntimeInstaller.prepare,storage,script.RuntimeBundle)
    if not ok then installStatus.Text='Runtime not installed: '..tostring(copy); return end
    local inserted,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before install EditRig IK runtime')
        assert(not storage:FindFirstChild('EditRigIKRuntime'),'runtime already exists')
        copy.Parent=storage
        ChangeHistoryService:SetWaypoint('Install EditRig IK runtime')
    end)
    if not inserted then copy:Destroy(); installStatus.Text='Runtime installation failed: '..tostring(err); return end
    installStatus.Text='Runtime installed. Start controllers explicitly after resolving joint ownership.'
end)
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
    local ok,result=pcall(RigInspector.inspect,model,Config)
    inspection.Text=if ok then RigInspector.format(result) else 'Inspection failed: '..tostring(result)
end)
local fields: {[string]: TextBox} = {}
for _, entry in ipairs({{'kind','Limit type'}, {'axis','Local axis'}, {'lower','Lower angle (degrees)'}, {'upper','Upper angle (degrees)'}, {'swing','Ball swing (degrees)'}, {'weight','IK joint influence (0–1)'}, {'control','Control name'}, {'impulse','Impulse name'}, {'frequency','Impulse damping (1/s)'}, {'holdKey','Hold KeyCode (optional)'}, {'impulseKey','Impulse KeyCode (optional)'}}) do
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
label('Ball keys use the selected axis: hold 1 radian; impulse 1 radian/second.',35)
local apply = Instance.new('TextButton')
apply.Size = UDim2.new(1, 0, 0, 32)
apply.BackgroundColor3 = Color3.fromRGB(61, 109, 172)
apply.TextColor3 = Color3.new(1,1,1)
apply.Text = 'Save limit metadata'
apply.Font = Enum.Font.SourceSansBold
apply.TextSize = 16
order(apply)
apply.Parent = root
local applyBatch=Instance.new('TextButton')
applyBatch.Size=UDim2.new(1,0,0,32); applyBatch.BackgroundColor3=Color3.fromRGB(61,109,172)
applyBatch.TextColor3=Color3.new(1,1,1); applyBatch.Text='Apply displayed settings to selected joints'
applyBatch.Font=Enum.Font.SourceSansBold; applyBatch.TextSize=15; order(applyBatch); applyBatch.Parent=root
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
status.Parent = widget
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.fromScale(0, 1)
status.Size = UDim2.new(1, 0, 0, 72)
status.BackgroundTransparency = 0
status.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
status.TextYAlignment = Enum.TextYAlignment.Top
local statusPadding = Instance.new('UIPadding')
statusPadding.PaddingTop = UDim.new(0, 6)
statusPadding.PaddingLeft = UDim.new(0, 10)
statusPadding.PaddingRight = UDim.new(0, 10)
statusPadding.Parent = status
local current: Instance? = nil
local axisButton=Instance.new('TextButton')
axisButton.Size=UDim2.new(1,0,0,32); axisButton.BackgroundColor3=Color3.fromRGB(61,109,172)
axisButton.TextColor3=Color3.new(1,1,1); axisButton.Text='Show selected joint axes and limits'
axisButton.Font=Enum.Font.SourceSansBold; axisButton.TextSize=16; order(axisButton); axisButton.Parent=root
local axisFolder: Folder?=nil
local axisGizmo: any=nil
local function hideAxes()
    if axisGizmo then axisGizmo:destroy(); axisGizmo=nil end
    if axisFolder then axisFolder:Destroy(); axisFolder=nil end
    axisButton.Text='Show selected joint axes and limits'
end
local function updateLimitPreview()
    if not axisGizmo then return end
    axisGizmo:setLimits({kind=fields.kind.Text,axis=string.upper(fields.axis.Text),lower=tonumber(fields.lower.Text),upper=tonumber(fields.upper.Text),swing=tonumber(fields.swing.Text)})
end
for _,key in ipairs({'kind','axis','lower','upper','swing'}) do
    fields[key]:GetPropertyChangedSignal('Text'):Connect(updateLimitPreview)
end
axisButton.MouseButton1Click:Connect(function()
    if axisGizmo then hideAxes(); return end
    if not current then status.Text='Select a Motor6D or Bone first.'; return end
    local folder=Instance.new('Folder'); folder.Name='EditRigIKAxisPreview'
    local ok,result=pcall(function()
        folder.Parent=game:GetService('CoreGui')
        return AxisGizmo.new(folder,LimitGeometry)
    end)
    if not ok then folder:Destroy(); status.Text='Cannot show axes: '..tostring(result); return end
    axisFolder=folder; axisGizmo=result
    updateLimitPreview()
    local updated,visible=pcall(function() return axisGizmo:update(current) end)
    if not updated or not visible then hideAxes(); status.Text='Cannot display this joint frame.'; return end
    axisButton.Text='Hide joint axes and limits'
    status.Text='X red, Y green, Z blue; yellow shows hinge range or ball swing. Ball twist is numeric only.'
end)
local axisUpdate=RunService.Heartbeat:Connect(function()
    if axisGizmo then
        local ok=pcall(function() axisGizmo:update(current) end)
        if not ok then hideAxes() end
    end
end)
plugin.Unloading:Connect(function() axisUpdate:Disconnect(); hideAxes() end)
local attrs = {kind='EditRigIK_Kind', axis='EditRigIK_Axis', lower='EditRigIK_LowerDegrees', upper='EditRigIK_UpperDegrees', swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
local defaults = {kind='Hinge', axis='X', lower=-90, upper=90, swing=90,weight=1,holdKey='',impulseKey=''}
local driveAttrs = {control='EditRigIK_Control',impulse='EditRigIK_Impulse',frequency='EditRigIK_Frequency'}
local inputAttrs = {holdKey='EditRigIK_HoldKey',impulseKey='EditRigIK_ImpulseKey'}
local function refresh()
    local items = Selection:Get()
    local item = if #items == 1 then items[1] else nil
    if item and (item:IsA('Motor6D') or item:IsA('Bone')) then
        current = item
        selectedLabel.Text = item.ClassName .. ': ' .. item:GetFullName()
        for key, box in pairs(fields) do
            local value = item:GetAttribute(attrs[key] or driveAttrs[key] or inputAttrs[key])
            local fallback = defaults[key] or (if key=='control' then item.Name elseif key=='impulse' then item.Name..'Impulse' else 4)
            box.Text = tostring(if value ~= nil then value else fallback)
        end
        status.Text = ''
    else
        current = nil
        selectedLabel.Text = if #items>1 then tostring(#items)..' selected. Form retains prior values; bulk applies displayed settings.' else 'Select one Motor6D or Bone in Explorer.'
        status.Text = ''
    end
end
button.Click:Connect(function() widget.Enabled = not widget.Enabled; button:SetActive(widget.Enabled); if widget.Enabled then refresh() end end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function() button:SetActive(widget.Enabled); if not widget.Enabled then hideAxes() end end)
Selection.SelectionChanged:Connect(refresh)
apply.MouseButton1Click:Connect(function()
    local item = current
    if not item or not item.Parent then status.Text = 'Select a valid joint first.'; return end
    local weight=tonumber(fields.weight.Text)
    if not weight then status.Text='Enter a joint influence.'; return end
    local ok, result = pcall(Config.validate, {kind=fields.kind.Text, axis=string.upper(fields.axis.Text), lower=tonumber(fields.lower.Text), upper=tonumber(fields.upper.Text), swing=tonumber(fields.swing.Text), weight=weight})
    if not ok then status.Text = 'Invalid settings: ' .. tostring(result); return end
    local frequency=tonumber(fields.frequency.Text)
    if not frequency then status.Text='Enter a damping frequency.'; return end
    local driveOk,drive=pcall(Config.validateDrive,{control=fields.control.Text,impulse=fields.impulse.Text,frequency=frequency},item.Name)
    if not driveOk then status.Text='Invalid control settings: '..tostring(drive); return end
    local keysOk,holdKey,impulseKey=pcall(function() return InputProfileBuilder.validateKey(fields.holdKey.Text),InputProfileBuilder.validateKey(fields.impulseKey.Text) end)
    if not keysOk then status.Text='Invalid input key: '..tostring(holdKey); return end
    ChangeHistoryService:SetWaypoint('Before EditRig IK limit metadata')
    for key, name in pairs(attrs) do item:SetAttribute(name, result[key]) end
    for key, name in pairs(driveAttrs) do item:SetAttribute(name, drive[key]) end
    item:SetAttribute(inputAttrs.holdKey,holdKey); item:SetAttribute(inputAttrs.impulseKey,impulseKey)
    item:SetAttribute('EditRigIK_SchemaVersion', 1)
    ChangeHistoryService:SetWaypoint('Save EditRig IK limit metadata')
    status.Text = 'Saved to ' .. item.Name .. '. Refresh actor and chain snapshots to use the changes.'
end)
local function batchValues()
    local weight=tonumber(fields.weight.Text)
    assert(weight,'enter a joint influence')
    return {kind=fields.kind.Text,axis=string.upper(fields.axis.Text),lower=tonumber(fields.lower.Text),upper=tonumber(fields.upper.Text),swing=tonumber(fields.swing.Text),weight=weight,control=fields.control.Text,impulse=fields.impulse.Text,frequency=tonumber(fields.frequency.Text),holdKey=fields.holdKey.Text,impulseKey=fields.impulseKey.Text}
end
applyBatch.MouseButton1Click:Connect(function()
    local items=Selection:Get()
    local ok,entries=pcall(function() return JointBatch.prepare(items,batchValues(),Config,InputProfileBuilder) end)
    if not ok then status.Text='Cannot apply joint settings: '..tostring(entries); return end
    local saved,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before batch EditRig IK settings')
        JointBatch.apply(entries)
        ChangeHistoryService:SetWaypoint('Batch EditRig IK settings')
    end)
    if not saved then status.Text='Batch save failed: '..tostring(err); return end
    status.Text='Saved '..#entries..' joints. Refresh actor and chain snapshots to use the changes.'
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
local refreshActor=Instance.new('TextButton')
refreshActor.Size=UDim2.new(1,0,0,32); refreshActor.BackgroundColor3=Color3.fromRGB(61,109,172)
refreshActor.TextColor3=Color3.new(1,1,1); refreshActor.Text='Refresh selected model actor settings'
refreshActor.Font=Enum.Font.SourceSansBold; refreshActor.TextSize=15; order(refreshActor); refreshActor.Parent=root
refreshActor.MouseButton1Click:Connect(function()
    local items=Selection:Get()
    local model=if #items==1 then items[1] else nil
    if not model or not model:IsA('Model') then status.Text='Select one model containing an actor.'; return end
    local folder=model:FindFirstChild('EditRigIKActor')
    local ok,err=pcall(Builder.prepareRefresh,folder)
    if not ok then status.Text='Cannot refresh actor: '..tostring(err); return end
    ChangeHistoryService:SetWaypoint('Before refresh EditRig IK actor')
    Builder.refresh(folder)
    ChangeHistoryService:SetWaypoint('Refresh EditRig IK actor')
    status.Text='Existing bindings refreshed. Restart active actor; newly configured joints are not added.'
end)
local addActorJoints=Instance.new('TextButton')
addActorJoints.Size=UDim2.new(1,0,0,32); addActorJoints.BackgroundColor3=Color3.fromRGB(61,109,172)
addActorJoints.TextColor3=Color3.new(1,1,1); addActorJoints.Text='Add newly configured joints to actor'
addActorJoints.Font=Enum.Font.SourceSansBold; addActorJoints.TextSize=15; order(addActorJoints); addActorJoints.Parent=root
addActorJoints.MouseButton1Click:Connect(function()
    local items=Selection:Get()
    local model=if #items==1 then items[1] else nil
    if not model or not model:IsA('Model') then status.Text='Select one model containing an actor.'; return end
    local folder=model:FindFirstChild('EditRigIKActor')
    local ok,entries=pcall(Builder.prepareAdd,folder)
    if not ok then status.Text='Cannot add joints: '..tostring(entries); return end
    if #entries==0 then status.Text='No new configured joints found.'; return end
    local saved,count=pcall(function()
        ChangeHistoryService:SetWaypoint('Before add EditRig IK actor joints')
        local n=Builder.addNew(folder)
        ChangeHistoryService:SetWaypoint('Add EditRig IK actor joints')
        return n
    end)
    if not saved then status.Text='Cannot add joints: '..tostring(count); return end
    status.Text='Added '..count..' joints. Restart the actor and regenerate input templates if needed.'
end)
local createInput=Instance.new('TextButton')
createInput.Size=UDim2.new(1,0,0,32); createInput.BackgroundColor3=Color3.fromRGB(61,109,172)
createInput.TextColor3=Color3.new(1,1,1); createInput.Text='Create disabled input template for model'
createInput.Font=Enum.Font.SourceSansBold; createInput.TextSize=15; order(createInput); createInput.Parent=root
createInput.MouseButton1Click:Connect(function()
    local items=Selection:Get()
    local model=if #items==1 then items[1] else nil
    if not model or not model:IsA('Model') then status.Text='Select a model containing an actor.'; return end
    if model:FindFirstChild('EditRigIKInputTemplate') then status.Text='Input template already exists; rename it before creating another.'; return end
    local ok,context=pcall(InputProfileBuilder.create,model:FindFirstChild('EditRigIKActor'))
    if not ok then status.Text='Cannot create input template: '..tostring(context); return end
    local inserted,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before create EditRig IK input template')
        assert(not model:FindFirstChild('EditRigIKInputTemplate'),'input template already exists')
        context.Parent=model
        ChangeHistoryService:SetWaypoint('Create EditRig IK input template')
    end)
    if not inserted then context:Destroy(); status.Text='Cannot create input template: '..tostring(err); return end
    status.Text='Disabled input template created. Clone under the local player, bind, then enable explicitly.'
end)
local gaitExample=Instance.new('TextButton')
gaitExample.Size=UDim2.new(1,0,0,32); gaitExample.BackgroundColor3=Color3.fromRGB(61,109,172)
gaitExample.TextColor3=Color3.new(1,1,1); gaitExample.Text='Add disabled Dino smooth-gait example'
gaitExample.Font=Enum.Font.SourceSansBold; gaitExample.TextSize=15; order(gaitExample); gaitExample.Parent=root
gaitExample.MouseButton1Click:Connect(function()
    local items=Selection:Get()
    local model=if #items==1 then items[1] else nil
    local ok,copy=pcall(GaitExampleInstaller.prepare,model,script.DinoGaitExample)
    if not ok then status.Text='Cannot add gait example: '..tostring(copy); return end
    local inserted,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before add disabled gait example')
        assert(not model:FindFirstChild(copy.Name),'gait example already exists')
        copy.Parent=model
        ChangeHistoryService:SetWaypoint('Add disabled gait example')
    end)
    if not inserted then copy:Destroy(); status.Text='Cannot add gait example: '..tostring(err); return end
    status.Text='Disabled example added. Review setup before enabling; install runtime and stop the old gait first.'
end)

-- Select each item in Explorer, then capture it explicitly so selection order
-- never decides chain direction.
local chainTitle=label('IK chain: capture root, end, endpoint and optional pole attachment.',42)
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
local gainField=chainNumberField('Correction gain (greater than 0 to 1)','1')
local chainStatus=label('No chain selections yet.',55)
local chainFeedback: TextLabel
local firstJoint: Instance?=nil
local lastJoint: Instance?=nil
local endpoint: Instance?=nil
local pole: Instance?=nil
local capturedControl: Instance?=nil
local capturedChain: any=nil
local function refreshChainStatus()
    chainStatus.Text='Root: '..(if firstJoint then firstJoint.Name else '—')..'  |  End: '..(if lastJoint then lastJoint.Name else '—')..'  |  Endpoint: '..(if endpoint then endpoint.Name else '—')..'  |  Pole: '..(if pole then pole.Name else 'none')
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
    gainField.Text=tostring(settings.gain)
    chainFeedback.Text='Loaded '..definition:GetFullName()..'. Keep it selected to save changes.'
end)
chainButton('Save settings to selected chain').MouseButton1Click:Connect(function()
    local definition=selectedOne()
    if not loadedChain or definition~=loadedChain then chainFeedback.Text='Select the loaded chain and load its settings before saving.'; return end
    local options={iterations=tonumber(iterationsField.Text),tolerance=tonumber(toleranceField.Text),maxStepDegrees=tonumber(maxStepField.Text),gain=tonumber(gainField.Text)}
    if not options.maxStepDegrees then chainFeedback.Text='Enter a maximum correction angle in degrees.'; return end
    if not options.gain then chainFeedback.Text='Enter a correction gain.'; return end
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
chainButton('Capture chain from selected IKControl').MouseButton1Click:Connect(function()
    local item=selectedOne()
    local ok,result=pcall(ChainDiscovery.inspect,item)
    if not ok then capturedControl=nil; capturedChain=nil; firstJoint=nil; lastJoint=nil; endpoint=nil; pole=nil; refreshChainStatus(); chainFeedback.Text='Cannot discover chain: '..tostring(result); return end
    capturedControl=item; capturedChain=result
    firstJoint=result.joints[1]; lastJoint=result.joints[#result.joints]
    endpoint=result.endpoint; pole=result.pole
    chainName.Text=string.sub(item.Name,1,64)
    local missing=0
    for _,joint in ipairs(result.joints) do if joint:GetAttribute('EditRigIK_SchemaVersion')~=1 then missing+=1 end end
    refreshChainStatus()
    chainFeedback.Text=string.format('Found %d joints; %d need limit metadata. %s Existing IKControl remains active; offsets are not copied. Custom solver is position-only.',#result.joints,missing,if endpoint then 'Endpoint captured.' else 'Select an endpoint attachment.')
end)
chainButton('Apply joint settings to captured IK chain').MouseButton1Click:Connect(function()
    local ok,entries=pcall(function()
        local joints=ChainDiscovery.verifyCapture(capturedControl,capturedChain)
        return JointBatch.prepare(joints,batchValues(),Config,InputProfileBuilder)
    end)
    if not ok then chainFeedback.Text='Cannot apply captured settings: '..tostring(entries); return end
    local saved,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before configure captured IKControl chain')
        JointBatch.apply(entries)
        ChangeHistoryService:SetWaypoint('Configure captured IKControl chain')
    end)
    if not saved then chainFeedback.Text='Cannot apply captured settings: '..tostring(err); return end
    chainFeedback.Text='Saved '..#entries..' joints. Review limits and axes; existing IKControl is unchanged.'
end)
chainButton('Set root joint from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or not (item:IsA('Motor6D') or item:IsA('Bone')) then chainFeedback.Text='Select one Motor6D or Bone as the root.'; return end
    capturedControl=nil; capturedChain=nil; firstJoint=item; refreshChainStatus()
end)
chainButton('Set end joint from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or not (item:IsA('Motor6D') or item:IsA('Bone')) then chainFeedback.Text='Select one Motor6D or Bone as the end.'; return end
    capturedControl=nil; capturedChain=nil; lastJoint=item; refreshChainStatus()
end)
chainButton('Set endpoint attachment from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or item.ClassName~='Attachment' then chainFeedback.Text='Select one regular Attachment as the endpoint.'; return end
    endpoint=item; refreshChainStatus()
end)
local endpointOffset=chainNumberField('New endpoint local X, Y, Z offset (studs)','0, 0, 0')
chainButton('Create endpoint at entered local offset').MouseButton1Click:Connect(function()
    local parsed,offset=pcall(ChainDiscovery.parseOffset,endpointOffset.Text)
    if not parsed then chainFeedback.Text='Invalid endpoint offset: '..tostring(offset); return end
    local ok,attachment,parent=pcall(ChainDiscovery.prepareEndpoint,lastJoint,offset)
    if not ok then chainFeedback.Text='Cannot create endpoint: '..tostring(attachment); return end
    local inserted,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before create EditRig IK endpoint')
        assert(not parent:FindFirstChild('EditRigIKEndpoint'),'endpoint name already exists')
        attachment.Parent=parent
        ChangeHistoryService:SetWaypoint('Create EditRig IK endpoint')
    end)
    if not inserted then attachment:Destroy(); chainFeedback.Text='Cannot create endpoint: '..tostring(err); return end
    endpoint=attachment; refreshChainStatus()
    chainFeedback.Text='Endpoint created at the entered offset. Verify its position on the rig.'
end)
chainButton('Set optional pole attachment from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or item.ClassName~='Attachment' then chainFeedback.Text='Select one regular Attachment as the pole.'; return end
    pole=item; refreshChainStatus()
end)
chainButton('Clear captured pole').MouseButton1Click:Connect(function()
    pole=nil; refreshChainStatus(); chainFeedback.Text='Pole cleared for the next chain.'
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
    local gain=tonumber(gainField.Text)
    if not gain then chainFeedback.Text='Enter a correction gain.'; return end
    local options={iterations=tonumber(iterationsField.Text),tolerance=tonumber(toleranceField.Text),maxStepDegrees=maxStep,gain=gain,pole=pole}
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

chainFeedback=status

local previewTitle=label('Clone pose preview: select a saved chain, then enter a world-space target offset in studs.',50)
local previewFrame=Instance.new('ViewportFrame')
previewFrame.Size=UDim2.new(1,0,0,260); previewFrame.BackgroundColor3=Color3.fromRGB(24,26,31)
previewFrame.Ambient=Color3.fromRGB(160,160,160); previewFrame.LightColor=Color3.fromRGB(255,255,255)
previewFrame.Visible=false
local preview: any=nil
local previewStatus: TextLabel
local function closePreview()
    if preview then preview:destroy(); preview=nil end
    previewFrame.Visible=false
end
chainButton('Open selected chain clone preview').MouseButton1Click:Connect(function()
    closePreview()
    local definition=selectedOne()
    local ok,result=pcall(function()
        local solver=require(script.PreviewSolver).new(require(script.PreviewLimits))
        local adapter=require(script.PreviewChainAdapter)
        local chainDefinition=require(script.PreviewChainDefinition)
        return require(script.PreviewSession).new(definition,previewFrame,{createChain=function(copy)
            return chainDefinition.new(copy,{exclusive=true},function(joints,point,options)
                return adapter.new(joints,point,options,solver)
            end)
        end})
    end)
    if not ok then previewStatus.Text='Cannot open preview: '..tostring(result); return end
    preview=result; previewFrame.Visible=true
    previewStatus.Text='Clone ready. Red is target; green is solved endpoint. Source model stays unchanged.'
end)
order(previewFrame); previewFrame.Parent=root
local previewX=chainNumberField('Preview target offset X (studs)','-1')
local previewY=chainNumberField('Preview target offset Y (studs)','1')
local previewZ=chainNumberField('Preview target offset Z (studs)','0')
chainButton('Solve clone preview').MouseButton1Click:Connect(function()
    if not preview then previewStatus.Text='Open a chain preview first.'; return end
    local x,y,z=tonumber(previewX.Text),tonumber(previewY.Text),tonumber(previewZ.Text)
    if not x or not y or not z then previewStatus.Text='Enter numeric target offsets.'; return end
    local ok,result=pcall(function() return preview:solveOffset(Vector3.new(x,y,z)) end)
    if not ok then previewStatus.Text='Preview solve failed: '..tostring(result); return end
    local limited={}
    for i,index in ipairs(result.limitedJoints) do
        if i>3 then table.insert(limited,'+'..(#result.limitedJoints-3)..' more'); break end
        table.insert(limited,tostring(index)..':'..string.sub(result.limitedJointNames[i],1,24))
    end
    previewStatus.Text=string.format('%s | error %.4f studs | pole %s | limited: %s',result.status,result.error,tostring(result.poleStatus),if #limited>0 then table.concat(limited,', ') else 'none')
end)
chainButton('Close clone preview').MouseButton1Click:Connect(function() closePreview(); previewStatus.Text='Preview closed.' end)
previewStatus=status
widget:GetPropertyChangedSignal('Enabled'):Connect(function() if not widget.Enabled then closePreview() end end)
plugin.Unloading:Connect(closePreview)

local navigation=Instance.new('Frame')
navigation.Name='SectionNavigation'; navigation.Size=UDim2.new(1,0,0,32)
navigation.BackgroundColor3=Color3.fromRGB(30,32,38); navigation.Parent=widget
for index,entry in ipairs({{'Rig',selectedLabel},{'Actor',createActor},{'Chain',chainTitle},{'Preview',previewTitle}}) do
    local item=Instance.new('TextButton')
    item.Name=entry[1]..'Section'; item.Position=UDim2.new((index-1)/4,0,0,0); item.Size=UDim2.new(.25,-1,1,0)
    item.BackgroundColor3=Color3.fromRGB(53,57,68); item.TextColor3=Color3.fromRGB(245,245,245)
    item.Font=Enum.Font.SourceSansBold; item.TextSize=15; item.Text=entry[1]; item.Parent=navigation
    local destination=entry[2]
    item.MouseButton1Click:Connect(function()
        local offset=destination.AbsolutePosition.Y-root.AbsolutePosition.Y+root.CanvasPosition.Y
        root.CanvasPosition=Vector2.new(0,math.max(0,offset-10))
    end)
end
