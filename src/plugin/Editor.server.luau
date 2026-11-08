--!strict
-- Authoring prototype: stores metadata and definitions without starting IK.
local Selection = game:GetService('Selection')
local ChangeHistoryService = game:GetService('ChangeHistoryService')
local RunService = game:GetService('RunService')
local Config = require(script.Config)
local Builder = require(script.DefinitionBuilder).new(Config)
local ChainBuilder = require(script.ChainBuilder).new(Config)
local ChainDiscovery = require(script.ChainDiscovery)
local ChainInference = require(script.ChainInference)
local IKConstraintBuilder = require(script.IKConstraintBuilder).new(Config)
local RigInspector = require(script.RigInspector)
local AxisGizmo = require(script.AxisGizmo)
local RigOverlay = require(script.RigOverlay)
local SavedLimitOverlay = require(script.SavedLimitOverlay)
local OverlaySelection = require(script.OverlaySelection)
local overlayPolicy = OverlaySelection.new()
local syncVisualSelection = function() end
local LimitGeometry = require(script.LimitGeometry).new(Config)
local LimitDraft = require(script.LimitDraft).new(Config)
local RuntimeInstaller = require(script.RuntimeInstaller)
local InputProfileBuilder = require(script.InputProfileBuilder)
local GaitExampleInstaller = require(script.GaitExampleInstaller)
local JointBatch = require(script.JointBatch)
local PanelComponents = require(script.PanelComponents)
local HingeLimitHandles = require(script.HingeLimitHandles)
local HingeDragMath = require(script.HingeDragMath)
local UserInputService = game:GetService('UserInputService')
local panel = nil
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
local overlayButton=Instance.new('TextButton')
overlayButton.Size=UDim2.new(1,0,0,32); overlayButton.BackgroundColor3=Color3.fromRGB(61,109,172)
overlayButton.TextColor3=Color3.new(1,1,1); overlayButton.Text='Show selected model joints in 3D'; overlayButton.Font=Enum.Font.SourceSansBold; overlayButton.TextSize=16
order(overlayButton); overlayButton.Parent=root
local overlayStatus=label('Select a Workspace rig to show its joints. Click a marker to select that joint.',40)
local rigOverlay,overlayFolder,overlayModel,savedLimitOverlay,savedLimitFolder=nil,nil,nil,nil,nil
local savedLimitStatus=''
local function hideRigOverlay()
    if savedLimitOverlay then savedLimitOverlay:destroy(); savedLimitOverlay=nil end
    if savedLimitFolder then savedLimitFolder:Destroy(); savedLimitFolder=nil end
    if rigOverlay then rigOverlay:destroy(); rigOverlay=nil end
    if overlayFolder then overlayFolder:Destroy(); overlayFolder=nil end
    overlayModel=nil; overlayButton.Text='Show selected model joints in 3D'
end
local function showRigOverlay(model)
    local folder=Instance.new('Folder'); folder.Name='EditRigIKRigOverlay'
    local ok,result=pcall(function()
        folder.Parent=game:GetService('CoreGui')
        return RigOverlay.new(model,folder,function(joint) Selection:Set({joint}) end)
    end)
    if not ok then folder:Destroy(); overlayStatus.Text='Cannot show joints: '..tostring(result); return end
    overlayFolder=folder; rigOverlay=result; overlayModel=model
    local updated,err=pcall(function() rigOverlay:update() end)
    if not updated then hideRigOverlay(); overlayStatus.Text='Cannot update joints: '..tostring(err); return end
    local limitFolder=Instance.new('Folder'); limitFolder.Name='SavedLimitGuides'; limitFolder.Parent=folder
    local limitsOk,limits=pcall(SavedLimitOverlay.new,model,limitFolder,Config,AxisGizmo,LimitGeometry,24)
    if limitsOk then savedLimitOverlay=limits; savedLimitFolder=limitFolder; savedLimitStatus=''
    else limitFolder:Destroy(); savedLimitStatus='Saved guides unavailable.' end
    overlayButton.Text='Hide 3D joints'
    overlayStatus.Text=tostring(rigOverlay:count())..' joints. Cyan markers select joints; yellow marks the selection. '..savedLimitStatus
end
overlayButton.MouseButton1Click:Connect(function()
    if rigOverlay then overlayPolicy:hideOverlay(); hideRigOverlay(); overlayStatus.Text='3D joints hidden until selection changes or the panel reopens.'; return end
    overlayPolicy:showOverlay(); syncVisualSelection()
end)
local lastOverlayEdit=RunService:IsEdit()
local overlayUpdate=RunService.Heartbeat:Connect(function()
    local edit=RunService:IsEdit()
    if edit~=lastOverlayEdit then lastOverlayEdit=edit; syncVisualSelection() end
    if rigOverlay then
        if not edit or not overlayModel:IsDescendantOf(workspace) then hideRigOverlay(); overlayStatus.Text='3D joints hidden.'; return end
        local items=Selection:Get(); local selected=if #items==1 then items[1] else nil
        local ok=pcall(function() rigOverlay:update(selected) end)
        if not ok then hideRigOverlay(); overlayStatus.Text='3D joints hidden after an update error.' end
        if savedLimitOverlay then
            local good,shown,total=pcall(function() return savedLimitOverlay:update(selected) end)
            if not good then
                savedLimitOverlay:destroy(); savedLimitOverlay=nil; savedLimitStatus='Saved guides unavailable.'
                if savedLimitFolder then savedLimitFolder:Destroy(); savedLimitFolder=nil end
            else
                savedLimitStatus=tostring(shown)..' saved limits shown of '..tostring(total)..' valid (maximum 24).'
            end
            overlayStatus.Text=tostring(rigOverlay:count())..' joints. '..savedLimitStatus
        end
    end
end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function() if not widget.Enabled then hideRigOverlay() end end)
plugin.Unloading:Connect(function() overlayUpdate:Disconnect(); hideRigOverlay() end)
local limitStateLabel=label('Limit settings: select one joint.',60)
limitStateLabel.TextColor3=Color3.fromRGB(255,204,111)
local fields: {[string]: TextBox} = {}
for _, entry in ipairs({{'kind','Limit type'}, {'axis','Local axis'}, {'lower','Lower angle (degrees)'}, {'upper','Upper angle (degrees)'}, {'swing','Ball swing (degrees)'}, {'weight','IK joint influence (0–1)'}, {'control','Control name'}, {'impulse','Impulse name'}, {'frequency','Impulse damping (1/s)'}, {'holdKey','Hold KeyCode (optional)'}, {'reverseHoldKey','Reverse hold KeyCode (optional)'}, {'holdValue','Hold value'}, {'impulseKey','Impulse KeyCode (optional)'}, {'impulseValue','Impulse value (rad/s)'}}) do
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
    box.Name = entry[1] .. 'Input'
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
label('Hinge hold: -1 to 1. Ball hold: radians on the selected axis. Impulse: rad/s.',40)
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
local hingeNotice=label('Built-in IK: creates an enabled physical constraint from saved Motor6D hinge or ball settings.',40)
hingeNotice.TextColor3=Color3.fromRGB(255,204,111)
local createIKHinge=Instance.new('TextButton')
createIKHinge.Size=UDim2.new(1,0,0,32); createIKHinge.BackgroundColor3=Color3.fromRGB(61,109,172)
createIKHinge.TextColor3=Color3.new(1,1,1); createIKHinge.Text='Create built-in IK constraint for selected Motor6D'
createIKHinge.Font=Enum.Font.SourceSansBold; createIKHinge.TextSize=15; order(createIKHinge); createIKHinge.Parent=root
local createIKBatch=Instance.new('TextButton')
createIKBatch.Size=UDim2.new(1,0,0,32); createIKBatch.BackgroundColor3=Color3.fromRGB(61,109,172)
createIKBatch.TextColor3=Color3.new(1,1,1); createIKBatch.Text='Create IK constraints for selected Motor6Ds'
createIKBatch.Font=Enum.Font.SourceSansBold; createIKBatch.TextSize=15; order(createIKBatch); createIKBatch.Parent=root
local refreshIKConstraint=Instance.new('TextButton')
refreshIKConstraint.Size=UDim2.new(1,0,0,32); refreshIKConstraint.BackgroundColor3=Color3.fromRGB(61,109,172)
refreshIKConstraint.TextColor3=Color3.new(1,1,1); refreshIKConstraint.Text='Refresh generated IK constraint from saved settings'
refreshIKConstraint.Font=Enum.Font.SourceSansBold; refreshIKConstraint.TextSize=15; order(refreshIKConstraint); refreshIKConstraint.Parent=root
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
local limitKeys={'kind','axis','lower','upper','swing','weight'}
local baseline: {[string]: string}={}
local updatingFields=false
local limitDiscardNotice=false
local attributeConnection: RBXScriptConnection?=nil
local limitDraftStarted=false
local hingeHandles,hingeFolder,hingeJoint=nil,nil,nil
local hingeActive=false
local hingeButton=Instance.new('TextButton')
hingeButton.Name='EditHingeLimits3D'
hingeButton.Size=UDim2.new(1,0,0,32); hingeButton.BackgroundColor3=Color3.fromRGB(61,109,172)
hingeButton.TextColor3=Color3.new(1,1,1); hingeButton.Text='Edit hinge limits in 3D'
hingeButton.Font=Enum.Font.SourceSansBold; hingeButton.TextSize=16; order(hingeButton); hingeButton.Parent=root
local limitBinding=PanelComponents.bindLimitInputs({lower=fields.lower,upper=fields.upper,swing=fields.swing},function(key)
    if hingeHandles then hingeHandles:select(if key=='lower' or key=='upper' then key else nil) end
end)
local function stopHingeEdit(message, deactivated)
    if not hingeActive then return end
    hingeActive=false
    if hingeHandles then hingeHandles:destroy(); hingeHandles=nil end
    if hingeFolder then hingeFolder:Destroy(); hingeFolder=nil end
    hingeJoint=nil
    hingeButton.Text='Edit hinge limits in 3D'
    if not deactivated then plugin:Deactivate() end
    if message then status.Text=message end
end
local function limitInput()
    return {kind=fields.kind.Text,axis=string.upper(fields.axis.Text),lower=tonumber(fields.lower.Text),upper=tonumber(fields.upper.Text),swing=tonumber(fields.swing.Text),weight=tonumber(fields.weight.Text)}
end
local function rememberLimitFields()
    for _,key in ipairs(limitKeys) do baseline[key]=fields[key].Text end
end
local function limitFieldsChanged(): boolean
    for _,key in ipairs(limitKeys) do if baseline[key]~=fields[key].Text then return true end end
    return false
end
local function updateLimitState()
    if updatingFields then return end
    local state=LimitDraft.classify(current,limitInput(),limitDraftStarted or limitFieldsChanged())
    local messages={
        none='Limit settings: select one joint.',
        unconfigured='Unconfigured: example values are not saved. The limit guide is hidden until configured.',
        saved='Saved limit settings. Yellow guide shows the saved values.',
        draft='Unsaved limit changes. Yellow guide shows the draft.',
        invalid='Invalid limit input. Yellow guide is hidden; nothing was saved.',
        invalidSaved='Saved limit metadata is incomplete, invalid or unsupported. Review and save.',
    }
    limitStateLabel.Text=messages[state] or 'Limit state unavailable.'
    if limitDiscardNotice then limitStateLabel.Text..=' Previous joint edits were not saved.' end
    limitStateLabel.TextColor3=if state=='saved' then Color3.fromRGB(160,225,185) else Color3.fromRGB(255,204,111)
end
for _,key in ipairs(limitKeys) do fields[key]:GetPropertyChangedSignal('Text'):Connect(function() updateLimitState() end) end
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
    local classification=LimitDraft.classify(current,limitInput(),limitDraftStarted or limitFieldsChanged())
    -- Blank/invalid metadata never renders the numeric form's fallback values
    -- as if they were an authored limit.
    axisGizmo:setLimits(if OverlaySelection.showLimit(classification) then limitInput() else nil)
end
for _,key in ipairs(limitKeys) do
    fields[key]:GetPropertyChangedSignal('Text'):Connect(updateLimitPreview)
    fields[key]:GetPropertyChangedSignal('Text'):Connect(function()
        if hingeHandles and not updatingFields then hingeHandles:sync(current,limitInput()) end
    end)
end
local function showAxes()
    if not current then return end
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
end
axisButton.MouseButton1Click:Connect(function()
    if axisGizmo then stopHingeEdit(nil); overlayPolicy:hideAxes(); hideAxes(); status.Text='Joint guide hidden until selection changes or the panel reopens.'; return end
    overlayPolicy:showAxes(); syncVisualSelection()
end)
hingeButton.Activated:Connect(function()
    if hingeActive then stopHingeEdit('3D hinge editing stopped; draft values remain unsaved.'); return end
    if not widget.Enabled or not RunService:IsEdit() or not current then status.Text='Select one joint in Edit mode first.'; return end
    if not current:IsDescendantOf(workspace) then status.Text='Select a joint in Workspace to edit its viewport limits.'; return end
    local ok,config=pcall(Config.validate,limitInput())
    if not ok or config.kind~='Hinge' then status.Text='Enter valid hinge settings before editing in 3D.'; return end
    local state=LimitDraft.classify(current,limitInput())
    if state=='invalidSaved' then status.Text='Saved metadata is invalid. Review and save it before editing in 3D.'; return end
    limitDraftStarted=state=='unconfigured' or limitDraftStarted
    overlayPolicy:showAxes(); syncVisualSelection(); updateLimitState(); updateLimitPreview()
    local folder=Instance.new('Folder'); folder.Name='EditRigIKHingeHandles'; folder.Parent=game:GetService('CoreGui')
    local joint=current
    local created,handles=pcall(function()
        return HingeLimitHandles.new(folder,plugin:GetMouse(),Config,HingeDragMath,AxisGizmo.restFrame,function(bound,value)
            if hingeActive and current==joint then limitBinding:select(bound); limitBinding:setValue(bound,value) end
        end,function(bound)
            limitBinding:select(bound)
            if panel then
                panel:select('Joints')
                local page=panel.pages.Joints
                local row=fields[bound].Parent
                page.CanvasPosition=Vector2.new(0,math.max(0,page.CanvasPosition.Y+row.AbsolutePosition.Y-page.AbsolutePosition.Y-45))
            end
            status.Text='Drag the '..bound..' handle; changes are unsaved until you save limit metadata.'
        end)
    end)
    if not created then folder:Destroy(); status.Text='Cannot create hinge handles: '..tostring(handles); return end
    hingeFolder=folder; hingeHandles=handles; hingeJoint=joint
    if not hingeHandles:set(joint,limitInput()) then hingeHandles:destroy(); hingeHandles=nil; folder:Destroy(); hingeFolder=nil; status.Text='Cannot display this joint frame.'; return end
    hingeActive=true; hingeButton.Text='Stop editing hinge limits in 3D'
    local activated,err=pcall(function() plugin:Activate(true) end)
    if not activated then stopHingeEdit('Cannot activate viewport editing: '..tostring(err)); return end
    status.Text='Drag a gold endpoint to edit its draft limit. Press Escape to cancel a drag; save to apply.'
end)
plugin.Deactivation:Connect(function() stopHingeEdit('3D hinge editing stopped; draft values remain unsaved.',true) end)
UserInputService.InputBegan:Connect(function(input)
    if hingeActive and input.KeyCode==Enum.KeyCode.Escape and not UserInputService:GetFocusedTextBox() and hingeHandles then hingeHandles:cancel(true) end
end)
local axisUpdate=RunService.Heartbeat:Connect(function()
    if hingeActive then
        if not RunService:IsEdit() or not widget.Enabled or current~=hingeJoint or not hingeJoint.Parent then
            stopHingeEdit('3D hinge editing stopped; draft values remain unsaved.')
        elseif hingeHandles then
            local ok,visible=pcall(function() return hingeHandles:update() end)
            if not ok then stopHingeEdit('3D hinge editing stopped: '..tostring(visible)) end
        end
    end
    if axisGizmo then
        local ok,visible=pcall(function() return axisGizmo:update(current) end)
        if not ok or not visible or not RunService:IsEdit() then hideAxes() end
    end
end)
plugin.Unloading:Connect(function() stopHingeEdit(nil); limitBinding:destroy(); axisUpdate:Disconnect(); hideAxes() end)
local attrs = {kind='EditRigIK_Kind', axis='EditRigIK_Axis', lower='EditRigIK_LowerDegrees', upper='EditRigIK_UpperDegrees', swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
local defaults = {kind='Hinge', axis='X', lower=-90, upper=90, swing=90,weight=1,holdKey='',reverseHoldKey='',holdValue=1,impulseKey='',impulseValue=1}
local driveAttrs = {control='EditRigIK_Control',impulse='EditRigIK_Impulse',frequency='EditRigIK_Frequency'}
local inputAttrs = {holdKey='EditRigIK_HoldKey',reverseHoldKey='EditRigIK_ReverseHoldKey',holdValue='EditRigIK_HoldValue',impulseKey='EditRigIK_ImpulseKey',impulseValue='EditRigIK_ImpulseValue'}
local function refresh()
    local items = Selection:Get()
    local item = if #items == 1 then items[1] else nil
    local discarded=current~=nil and current~=item and (limitDraftStarted or limitFieldsChanged() or LimitDraft.classify(current,limitInput())=='draft')
    if current~=item then stopHingeEdit(nil); limitBinding:abandon(); limitBinding:select(nil); limitDraftStarted=false end
    if attributeConnection then attributeConnection:Disconnect(); attributeConnection=nil end
    updatingFields=true
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
    rememberLimitFields(); updatingFields=false; limitDiscardNotice=discarded
    if current then attributeConnection=current.AttributeChanged:Connect(function() stopHingeEdit('Joint metadata changed; 3D editing stopped.'); updateLimitState(); updateLimitPreview() end) end
    updateLimitState()
    updateLimitPreview()
end
syncVisualSelection=function()
    local items=Selection:Get(); local item=if #items==1 then items[1] else nil
    local joint=if item and (item:IsA('Motor6D') or item:IsA('Bone')) and item:IsDescendantOf(workspace) then item else nil
    local model=nil
    if item and item:IsA('Model') and item:IsDescendantOf(workspace) then
        for _,descendant in ipairs(item:GetDescendants()) do
            if descendant:IsA('Motor6D') or descendant:IsA('Bone') then model=item; break end
        end
    elseif joint then
        model=if overlayModel and joint:IsDescendantOf(overlayModel) then overlayModel else joint:FindFirstAncestorOfClass('Model')
        if model and not model:IsDescendantOf(workspace) then model=nil end
    end
    local desiredModel,desiredJoint=overlayPolicy:update(widget.Enabled,RunService:IsEdit(),item,model,joint)
    if rigOverlay and desiredModel~=overlayModel then hideRigOverlay() end
    if desiredModel and not rigOverlay then showRigOverlay(desiredModel) end
    if not desiredJoint then hideAxes() elseif not axisGizmo then showAxes() end
end
button.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function()
    button:SetActive(widget.Enabled)
    if widget.Enabled then refresh() end
    if not widget.Enabled then stopHingeEdit(nil) end
    syncVisualSelection()
end)
Selection.SelectionChanged:Connect(function() refresh(); syncVisualSelection() end)
createIKHinge.MouseButton1Click:Connect(function()
    local items=Selection:Get(); local joint=if #items==1 then items[1] else nil
    local ok,prepared=pcall(IKConstraintBuilder.prepare,joint)
    if not ok then status.Text='Cannot create IK constraint: '..tostring(prepared); return end
    local saved,result=pcall(function()
        ChangeHistoryService:SetWaypoint('Before create EditRig IK constraint')
        local created=IKConstraintBuilder.apply(prepared)
        ChangeHistoryService:SetWaypoint('Create EditRig IK constraint')
        return created
    end)
    if not saved then status.Text='Cannot create IK constraint: '..tostring(result); return end
    status.Text='Created '..result.Name..'. Test the rig in Play; use Undo to remove.'
end)
createIKBatch.MouseButton1Click:Connect(function()
    local ok,prepared=pcall(IKConstraintBuilder.prepareBatch,Selection:Get())
    if not ok then status.Text='Cannot create IK constraints: '..tostring(prepared); return end
    local saved,result=pcall(function()
        ChangeHistoryService:SetWaypoint('Before create EditRig IK constraint batch')
        local created=IKConstraintBuilder.applyBatch(prepared)
        ChangeHistoryService:SetWaypoint('Create EditRig IK constraint batch')
        return created
    end)
    if not saved then status.Text='Cannot create IK constraints: '..tostring(result); return end
    status.Text='Created '..#result..' IK constraints. Test in Play; use Undo to remove.'
end)
refreshIKConstraint.MouseButton1Click:Connect(function()
    local items=Selection:Get(); local joint=if #items==1 then items[1] else nil
    local ok,prepared=pcall(IKConstraintBuilder.prepareRefresh,joint)
    if not ok then status.Text='Cannot refresh IK constraint: '..tostring(prepared); return end
    local saved,result=pcall(function()
        ChangeHistoryService:SetWaypoint('Before refresh EditRig IK constraint')
        local updated=IKConstraintBuilder.refresh(prepared)
        ChangeHistoryService:SetWaypoint('Refresh EditRig IK constraint')
        return updated
    end)
    if not saved then status.Text='Cannot refresh IK constraint: '..tostring(result); return end
    status.Text='Refreshed '..result.Name..'. Test the rig in Play; use Undo to revert.'
end)
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
    local holdValue,impulseValue=tonumber(fields.holdValue.Text),tonumber(fields.impulseValue.Text)
    if holdValue==nil or impulseValue==nil then status.Text='Enter numeric hold and impulse values.'; return end
    local keysOk,holdKey,reverseHoldKey,impulseKey=pcall(function()
        InputProfileBuilder.validateAmount(result.kind,'Hold',holdValue)
        InputProfileBuilder.validateAmount(result.kind,'Impulse',impulseValue)
        local forward,reverse=InputProfileBuilder.validateHoldKeys(fields.holdKey.Text,fields.reverseHoldKey.Text)
        return forward,reverse,InputProfileBuilder.validateKey(fields.impulseKey.Text)
    end)
    if not keysOk then status.Text='Invalid input settings: '..tostring(holdKey); return end
    ChangeHistoryService:SetWaypoint('Before EditRig IK limit metadata')
    for key, name in pairs(attrs) do item:SetAttribute(name, result[key]) end
    for key, name in pairs(driveAttrs) do item:SetAttribute(name, drive[key]) end
    item:SetAttribute(inputAttrs.holdKey,holdKey); item:SetAttribute(inputAttrs.reverseHoldKey,reverseHoldKey); item:SetAttribute(inputAttrs.impulseKey,impulseKey)
    item:SetAttribute(inputAttrs.holdValue,holdValue); item:SetAttribute(inputAttrs.impulseValue,impulseValue)
    item:SetAttribute('EditRigIK_SchemaVersion', 1)
    ChangeHistoryService:SetWaypoint('Save EditRig IK limit metadata')
    rememberLimitFields(); limitDraftStarted=false; limitDiscardNotice=false; updateLimitState()
    status.Text = 'Saved to ' .. item.Name .. '. Refresh actor and chain snapshots to use the changes.'
end)
local function batchValues()
    local weight=tonumber(fields.weight.Text)
    assert(weight,'enter a joint influence')
    local holdValue,impulseValue=tonumber(fields.holdValue.Text),tonumber(fields.impulseValue.Text)
    assert(holdValue~=nil and impulseValue~=nil,'enter numeric hold and impulse values')
    return {kind=fields.kind.Text,axis=string.upper(fields.axis.Text),lower=tonumber(fields.lower.Text),upper=tonumber(fields.upper.Text),swing=tonumber(fields.swing.Text),weight=weight,control=fields.control.Text,impulse=fields.impulse.Text,frequency=tonumber(fields.frequency.Text),holdKey=fields.holdKey.Text,reverseHoldKey=fields.reverseHoldKey.Text,holdValue=holdValue,impulseKey=fields.impulseKey.Text,impulseValue=impulseValue}
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
label('Actor modes: animated accepts external joint writes; absolute can change the animation pose.',45)
local function actorModeField(caption,default)
    local row=Instance.new('Frame'); row.Size=UDim2.new(1,0,0,30); row.BackgroundTransparency=1; order(row); row.Parent=root
    local title=Instance.new('TextLabel'); title.Size=UDim2.new(.53,0,1,0); title.BackgroundTransparency=1
    title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Font=Enum.Font.SourceSans; title.TextSize=16; title.Text=caption; title.Parent=row
    local box=Instance.new('TextBox'); box.Position=UDim2.new(.53,0,0,0); box.Size=UDim2.new(.47,0,1,0)
    box.BackgroundColor3=Color3.fromRGB(60,63,72); box.TextColor3=Color3.new(1,1,1); box.Font=Enum.Font.SourceSans; box.TextSize=16
    box.ClearTextOnFocus=false; box.Text=default; box.Parent=row
    return box
end
local actorBase=actorModeField('Base: fixed / animated','fixed')
local actorLimit=actorModeField('Limits: offset / absolute','offset')
local loadedActor=nil
local function actorOptionButton(title)
    local item=Instance.new('TextButton'); item.Size=UDim2.new(1,0,0,32); item.BackgroundColor3=Color3.fromRGB(61,109,172)
    item.TextColor3=Color3.new(1,1,1); item.Text=title; item.Font=Enum.Font.SourceSansBold; item.TextSize=15; order(item); item.Parent=root
    return item
end
actorOptionButton('Load selected model actor modes').MouseButton1Click:Connect(function()
    loadedActor=nil
    local items=Selection:Get(); local model=if #items==1 then items[1] else nil
    local folder=if model and model:IsA('Model') then model:FindFirstChild('EditRigIKActor') else nil
    local ok,result=pcall(Builder.readActorOptions,folder)
    if not ok then status.Text='Cannot load actor modes: '..tostring(result); return end
    loadedActor=folder; actorBase.Text=result.baseMode; actorLimit.Text=result.limitMode
    status.Text='Actor modes loaded. Absolute limits may change the animation pose.'
end)
actorOptionButton('Save loaded actor modes').MouseButton1Click:Connect(function()
    local items=Selection:Get(); local model=if #items==1 then items[1] else nil
    if not loadedActor or not model or not model:IsA('Model') or loadedActor.Parent~=model or model:FindFirstChild('EditRigIKActor')~=loadedActor then
        status.Text='Select the same model and load its actor modes before saving.'; return
    end
    local ok,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before EditRig IK actor modes')
        Builder.writeActorOptions(loadedActor,{baseMode=actorBase.Text,limitMode=actorLimit.Text})
        ChangeHistoryService:SetWaypoint('EditRig IK actor modes')
    end)
    if not ok then status.Text='Cannot save actor modes: '..tostring(err); return end
    status.Text='Actor modes saved. Restart active actors to apply them.'
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
local speedField=chainNumberField('Max joint speed (degrees/s; 0 = off)','0')
local chainBaseField=chainNumberField('Chain base mode (fixed / animated)','fixed')
local chainBaseNotice=label('Animated mode accepts external joint writes; coordinate Animator and IKControl ownership.',40)
chainBaseNotice.TextColor3=Color3.fromRGB(255,204,111)
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
local inferenceStatus=label('Inferred paths are suggestions. Review the root, end and endpoint before creating a chain.',55)
inferenceStatus.AutomaticSize=Enum.AutomaticSize.Y
inferenceStatus.TextYAlignment=Enum.TextYAlignment.Top
chainButton('Infer chain from selected joint').MouseButton1Click:Connect(function()
    local joint=selectedOne()
    if not joint or not (joint:IsA('Motor6D') or joint:IsA('Bone')) then inferenceStatus.Text='Select one Motor6D or Bone. Previous capture is unchanged.'; return end
    local model=joint:FindFirstAncestorWhichIsA('Model')
    local ok,result=pcall(ChainInference.infer,model,joint)
    if not ok then inferenceStatus.Text='Cannot infer chain: '..tostring(result)..'. Previous capture is unchanged.'; return end
    if not result.ok then inferenceStatus.Text='Cannot infer chain: '..result.message..' Use the capture buttons below to choose a root, end and endpoint. Previous capture is unchanged.'; return end
    capturedControl=nil; capturedChain=nil; firstJoint=result.root; lastJoint=result.endJoint; endpoint=result.endpoint; pole=nil
    refreshChainStatus()
    local names={}
    for _,j in ipairs(result.joints) do table.insert(names,j.Name) end
    inferenceStatus.Text='Inferred suggestion: '..table.concat(names,' → ')..'  |  Endpoint: '..result.endpoint.Name..'. Review and correct with the capture buttons below; no limits or chain were saved.'
end)
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
    speedField.Text=tostring(settings.maxSpeedDegrees)
    chainBaseField.Text=settings.baseMode
    chainFeedback.Text='Loaded '..definition:GetFullName()..'. Keep it selected to save changes.'
end)
chainButton('Save settings to selected chain').MouseButton1Click:Connect(function()
    local definition=selectedOne()
    if not loadedChain or definition~=loadedChain then chainFeedback.Text='Select the loaded chain and load its settings before saving.'; return end
    local options={iterations=tonumber(iterationsField.Text),tolerance=tonumber(toleranceField.Text),maxStepDegrees=tonumber(maxStepField.Text),gain=tonumber(gainField.Text),maxSpeedDegrees=tonumber(speedField.Text),baseMode=chainBaseField.Text}
    if not options.maxStepDegrees then chainFeedback.Text='Enter a maximum correction angle in degrees.'; return end
    if not options.gain then chainFeedback.Text='Enter a correction gain.'; return end
    if not options.maxSpeedDegrees then chainFeedback.Text='Enter a maximum speed, or 0 to disable it.'; return end
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
    chainFeedback.Text=string.format('Found %d joints; %d need limit metadata. %s Existing IKControl is unchanged; offsets are not copied. Custom solver is position-only.',#result.joints,missing,if endpoint then 'Endpoint captured.' else 'Select an endpoint attachment.')
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
chainButton('Create IK constraints for captured motor chain').MouseButton1Click:Connect(function()
    local ok,prepared=pcall(function()
        local joints=ChainDiscovery.verifyCapture(capturedControl,capturedChain)
        return IKConstraintBuilder.prepareBatch(joints)
    end)
    if not ok then chainFeedback.Text='Cannot create captured constraints: '..tostring(prepared); return end
    local saved,result=pcall(function()
        ChangeHistoryService:SetWaypoint('Before create captured IK constraints')
        local created=IKConstraintBuilder.applyBatch(prepared)
        ChangeHistoryService:SetWaypoint('Create captured IK constraints')
        return created
    end)
    if not saved then chainFeedback.Text='Cannot create captured constraints: '..tostring(result); return end
    chainFeedback.Text='Created '..#result..' physical constraints. Test in Play; use Undo to remove.'
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
    local speed=tonumber(speedField.Text)
    if not speed then chainFeedback.Text='Enter a maximum speed, or 0 to disable it.'; return end
    local options={iterations=tonumber(iterationsField.Text),tolerance=tonumber(toleranceField.Text),maxStepDegrees=maxStep,gain=gain,maxSpeedDegrees=speed,baseMode=chainBaseField.Text,pole=pole}
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
local previewStatus=label('Preview is closed.',55)
previewStatus.TextYAlignment=Enum.TextYAlignment.Top
local previewFrame=Instance.new('ViewportFrame')
previewFrame.Size=UDim2.new(1,0,0,260); previewFrame.BackgroundColor3=Color3.fromRGB(24,26,31)
previewFrame.Ambient=Color3.fromRGB(160,160,160); previewFrame.LightColor=Color3.fromRGB(255,255,255)
previewFrame.Visible=false
local preview: any=nil
local previewGuard: any=nil
local function closePreview()
    if previewGuard then previewGuard:destroy(); previewGuard=nil end
    if preview then preview:destroy(); preview=nil end
    previewFrame.Visible=false
end
chainButton('Open selected chain clone preview').MouseButton1Click:Connect(function()
    closePreview()
    if not RunService:IsEdit() then previewStatus.Text='Stop Play before opening a preview.'; return end
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
    local guarded,guard=pcall(function()
        local model=definition.Parent.Parent
        return require(script.PreviewGuard).new(model,definition,Selection,RunService,function(reason)
            closePreview(); previewStatus.Text='Preview closed: '..reason..'. Reopen the chain to preview again.'
        end)
    end)
    if not guarded then closePreview(); previewStatus.Text='Cannot monitor preview: '..tostring(guard); return end
    previewGuard=guard
    previewStatus.Text='Clone ready. Red is target; green is solved endpoint. Source model stays unchanged.'
end)
order(previewFrame); previewFrame.Parent=root
local previewX=chainNumberField('Preview target offset X (studs)','-1')
local previewY=chainNumberField('Preview target offset Y (studs)','1')
local previewZ=chainNumberField('Preview target offset Z (studs)','0')
chainButton('Solve clone preview').MouseButton1Click:Connect(function()
    if not preview then previewStatus.Text='Open a chain preview first.'; return end
    if not previewGuard or not previewGuard:check() then return end
    local x,y,z=tonumber(previewX.Text),tonumber(previewY.Text),tonumber(previewZ.Text)
    if not x or not y or not z then previewStatus.Text='Enter numeric target offsets.'; return end
    local ok,result=pcall(function() return preview:solveOffset(Vector3.new(x,y,z)) end)
    if not ok then closePreview(); previewStatus.Text='Preview closed after solve error: '..tostring(result); return end
    local limited={}
    for i,index in ipairs(result.limitedJoints) do
        if i>3 then table.insert(limited,'+'..(#result.limitedJoints-3)..' more'); break end
        table.insert(limited,tostring(index)..':'..string.sub(result.limitedJointNames[i],1,24))
    end
    previewStatus.Text=string.format('%s | error %.4f studs | pole %s | clamped during solve: %s',if result.converged then 'Reached' else 'Not reached',result.error,tostring(result.poleStatus),if #limited>0 then table.concat(limited,', ') else 'none')
end)
chainButton('Close clone preview').MouseButton1Click:Connect(function() closePreview(); previewStatus.Text='Preview closed.' end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function() if not widget.Enabled then closePreview() end end)
plugin.Unloading:Connect(closePreview)

local ghostTitle=label('Viewport simulation: select a saved chain. Uses the chain’s saved limits; refresh them from joints after editing. The translucent rig is a temporary preview.',80)
local ghostStatus=label('Simulation is closed. Surface alignment is not available yet.',55)
ghostStatus.AutomaticSize=Enum.AutomaticSize.Y; ghostStatus.TextYAlignment=Enum.TextYAlignment.Top
local ghostOffsetLabel=label('Target offset X, Y, Z (world studs)',25)
local ghostOffset=Instance.new('TextBox'); ghostOffset.Size=UDim2.new(1,0,0,30); ghostOffset.BackgroundColor3=Color3.fromRGB(60,63,72)
ghostOffset.TextColor3=Color3.new(1,1,1); ghostOffset.Font=Enum.Font.SourceSans; ghostOffset.TextSize=16
ghostOffset.Text='0, 0, 0'; ghostOffset.ClearTextOnFocus=false; order(ghostOffset); ghostOffset.Parent=root
local ghost,ghostGuard,ghostTarget,ghostWorld,ghostGui,ghostAncestry=nil,nil,nil,nil,nil,nil
local surfacePanel,surfaceGuide,surfaceSource,surfaceSnapshot=nil,nil,nil,nil
local poseQueue,ghostDesiredOrientation,ghostJointCount,previewFallback=nil,nil,0,false
local pendingTarget=nil
local function closeGhost()
    pendingTarget=nil
    if poseQueue then poseQueue:cancel(); poseQueue=nil end
    ghostDesiredOrientation=nil; ghostJointCount=0; surfaceSnapshot=nil; previewFallback=false
    if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
    surfaceSource=nil
    if surfacePanel then surfacePanel:setContext('Start a viewport simulation for a saved chain.',false) end
    if ghostAncestry then ghostAncestry:Disconnect(); ghostAncestry=nil end
    if ghostGuard then ghostGuard:destroy(); ghostGuard=nil end
    if ghostTarget then ghostTarget:destroy(); ghostTarget=nil end
    if ghost then ghost:destroy(); ghost=nil end
    if ghostGui then ghostGui:Destroy(); ghostGui=nil end
    if ghostWorld then ghostWorld:Destroy(); ghostWorld=nil end
end
local function checkGhostResources()
    if not ghost then return false end
    if not ghostWorld or ghostWorld.Parent~=workspace or not ghostGui or ghostGui.Parent~=game:GetService('CoreGui') or not ghostTarget or not ghost:isValid() or not ghostTarget:isValid() then
        closeGhost(); ghostStatus.Text='Simulation closed: a temporary preview object was removed or moved. Start it again.'
        return false
    end
    return true
end
local ghostStartButton=chainButton('Start viewport simulation')
ghostStartButton.MouseButton1Click:Connect(function()
    closeGhost(); closePreview()
    if not RunService:IsEdit() then ghostStatus.Text='Stop Play before starting simulation.'; return end
    local definition=selectedOne()
    if not definition or not definition:IsA('Folder') or definition:GetAttribute('SchemaVersion')~=1 or not definition.Parent or definition.Parent.Name~='EditRigIKChains' or not definition.Parent.Parent or not definition.Parent.Parent:IsA('Model') then
        ghostStatus.Text='Select a saved chain definition first.'; return
    end
    local ok,result=pcall(function()
        assert(not workspace:FindFirstChild('EditRigIKGhostSession'),'another temporary ghost session already exists')
        ghostWorld=Instance.new('Folder'); ghostWorld.Name='EditRigIKGhostSession'; ghostWorld.Archivable=false
        ghostGui=Instance.new('Folder'); ghostGui.Name='EditRigIKGhostGui'; ghostGui.Archivable=false
        local solver=require(script.PreviewSolver).new(require(script.PreviewLimits))
        local adapter=require(script.PreviewChainAdapter)
        local chainDefinition=require(script.PreviewChainDefinition)
        ghost=require(script.WorldGhostSession).new(definition,ghostWorld,{createChain=function(copy)
            return chainDefinition.new(copy,{exclusive=true},function(joints,point,options)
                return adapter.new(joints,point,options,solver)
            end)
        end})
        ghostJointCount=#definition.Joints:GetChildren()
        poseQueue=require(script.PosePreviewQueue).new(math.min(40,definition:GetAttribute('Iterations')))
        ghostTarget=require(script.ViewportTargetHandle).new(ghostWorld,ghostGui,ghost:startTarget(),function(target)
            if checkGhostResources() then
                local moved,err=pcall(function()
                    ghostTarget:setPosition(target); ghostOffset.Text=ChainDiscovery.formatOffset(target-ghost:startTarget())
                    if ghostDesiredOrientation then poseQueue:request(target,ghostDesiredOrientation) else pendingTarget=target end
                end)
                if not moved then closeGhost(); ghostStatus.Text='Simulation closed after target error: '..tostring(err) end
            end
        end)
        ghostGuard=require(script.PreviewGuard).new(definition.Parent.Parent,definition,Selection,RunService,function(reason)
            closeGhost(); ghostStatus.Text='Simulation closed: '..reason..'. Reopen the chain to try again.'
        end)
        ghostWorld.Parent=workspace; ghostGui.Parent=game:GetService('CoreGui')
        ghostAncestry=ghostWorld.AncestryChanged:Connect(function()
            if ghostWorld and not ghostWorld:IsDescendantOf(workspace) then closeGhost(); ghostStatus.Text='Simulation closed: temporary preview was removed.' end
        end)
        return true
    end)
    if not ok then closeGhost(); ghostStatus.Text='Cannot start simulation: '..tostring(result); return end
    surfaceSource=definition.Parent.Parent
    local endpointRef=definition:FindFirstChild('Endpoint')
    local endpointName=if endpointRef and endpointRef:IsA('ObjectValue') and endpointRef.Value then endpointRef.Value:GetFullName() else '(unavailable)'
    if surfacePanel then surfacePanel:setContext('Chain: '..definition.Name..' · starting endpoint: '..endpointName,true) end
    ghostOffset.Text=ChainDiscovery.formatOffset(Vector3.zero)
    ghostStatus.Text='Preview uses saved chain limits. Refresh limits from joints after editing. Red: target; green: endpoint.'
end)
local ghostSetTargetButton=chainButton('Set viewport target offset')
ghostSetTargetButton.MouseButton1Click:Connect(function()
    if not ghost then ghostStatus.Text='Start viewport simulation first.'; return end
    if not checkGhostResources() then return end
    if not ghostGuard or not ghostGuard:check() then return end
    local ok,offset=pcall(ChainDiscovery.parseOffset,ghostOffset.Text)
    if not ok then ghostStatus.Text='Invalid target offset: '..tostring(offset); return end
    local setOk,err=pcall(function()
        local target=ghost:startTarget()+offset
        ghostTarget:setPosition(target)
        if ghostDesiredOrientation then poseQueue:request(target,ghostDesiredOrientation) else pendingTarget=target end
    end)
    if not setOk then closeGhost(); ghostStatus.Text='Simulation closed after target error: '..tostring(err) end
end)
local ghostResetButton=chainButton('Reset viewport simulation')
ghostResetButton.MouseButton1Click:Connect(function()
    if not ghost then ghostStatus.Text='Start viewport simulation first.'; return end
    if not checkGhostResources() then return end
    if not ghostGuard or not ghostGuard:check() then return end
    pendingTarget=nil
    if poseQueue then poseQueue:cancel() end
    ghostDesiredOrientation=nil
    surfaceSnapshot=nil
    if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
    if surfacePanel then surfacePanel:setResult('Preview reset. Check the scene surface again before aligning.') end
    local ok,err=pcall(function() ghost:reset(); local start=ghost:startTarget(); ghostTarget:setPosition(start); ghostTarget:setEndpoint(start) end)
    if not ok then closeGhost(); ghostStatus.Text='Simulation closed after reset error: '..tostring(err); return end
    ghostOffset.Text=ChainDiscovery.formatOffset(Vector3.zero)
    ghostStatus.Text='Preview reset to its starting pose.'
end)
local ghostEndButton=chainButton('End viewport simulation')
ghostEndButton.MouseButton1Click:Connect(function() closeGhost(); ghostStatus.Text='Simulation closed.' end)
local ghostUpdate=RunService.Heartbeat:Connect(function()
    if surfaceGuide and not surfaceGuide:isValid() then
        surfaceGuide:destroy(); surfaceGuide=nil
        surfaceSnapshot=nil; ghostDesiredOrientation=nil
        if poseQueue then poseQueue:cancel() end
        if surfacePanel then surfacePanel:setResult('Contact guide was removed. Check the scene surface again.') end
    end
    if not ghost or not checkGhostResources() then return end
    if not ghostGuard or not ghostGuard:check() then return end
    local job=poseQueue and poseQueue:next()
    if job then
        local ok,result=pcall(function()
            local solved=ghost:solveTarget(job.target,{iterations=1,targetOrientation=job.orientation,orientationTolerance=math.rad(1)})
            ghostTarget:setEndpoint(solved.endpointWorld); return solved
        end)
        if not ok then poseQueue:complete(job,nil); closeGhost(); ghostStatus.Text='Simulation closed after solve error: '..tostring(result); return end
        local accepted,state=poseQueue:complete(job,result)
        if accepted then
            local label=if state=='pending' then 'Solving' elseif state=='converged' then 'Reached' else 'Not reached'
            local message=string.format('%s · gap %.3f studs · orientation error %.1f° · step %d',label,result.error,math.deg(result.orientationError),job.iteration)
            if previewFallback then message..=' · heading fallback' end
            ghostStatus.Text=message
            if surfacePanel then surfacePanel:setResult(message..'\nPreview assumes support; original rig is unchanged.') end
        end
        return
    end
    if not pendingTarget then return end
    local target=pendingTarget; pendingTarget=nil
    local ok,result=pcall(function() local solved=ghost:solveTarget(target); ghostTarget:setEndpoint(solved.endpointWorld); return solved end)
    if not ok then closeGhost(); ghostStatus.Text='Simulation closed after solve error: '..tostring(result); return end
    ghostStatus.Text=string.format('%s | gap %.3f studs | %d iterations | clamped during solve: %d',if result.converged then 'Reached' else 'Not reached',result.error,result.iterations,#result.limitedJoints)
end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function() if not widget.Enabled then closeGhost() end end)
plugin.Unloading:Connect(function() ghostUpdate:Disconnect(); closeGhost() end)

-- The editor's existing controls are grouped into real pages; their callbacks
-- retain the same instances and authorization/undo behavior.
panel=PanelComponents.new(widget)
panel.root.Visible=false
for _,item in ipairs(root:GetChildren()) do
    if item:IsA('GuiObject') then
        local page
        if item==axisButton or item==hingeButton then page=panel.pages.Joints
        elseif item.LayoutOrder<limitStateLabel.LayoutOrder then page=panel.pages.Rig
        elseif item.LayoutOrder<createActor.LayoutOrder then page=panel.pages.Joints
        elseif item.LayoutOrder<chainTitle.LayoutOrder then page=panel.pages.Rig
        elseif item.LayoutOrder<previewTitle.LayoutOrder then page=panel.pages.Joints
        else page=panel.pages.Simulate end
        if item:IsA('TextButton') then
            item.BackgroundColor3=Color3.fromRGB(49,55,66); item.TextWrapped=true
            if item==apply then item.BackgroundColor3=Color3.fromRGB(42,115,151) end
        end
        item.Parent=page
    end
end
-- Keep viewport editing next to the numeric hinge bounds rather than below
-- the unrelated actor and input settings.
for _,item in ipairs(panel.pages.Joints:GetChildren()) do
    if item:IsA('GuiObject') then item.LayoutOrder*=10 end
end
hingeButton.LayoutOrder=fields.upper.Parent.LayoutOrder+1
axisButton.LayoutOrder=fields.upper.Parent.LayoutOrder+2
ghostTitle.LayoutOrder=1; ghostStatus.LayoutOrder=2; ghostOffsetLabel.LayoutOrder=3; ghostOffset.LayoutOrder=4
ghostStartButton.LayoutOrder=5; ghostSetTargetButton.LayoutOrder=6; ghostResetButton.LayoutOrder=7; ghostEndButton.LayoutOrder=8
local selectedJointLabel=selectedLabel:Clone()
selectedJointLabel.Name='SelectedJointContext'; selectedJointLabel.LayoutOrder=0; selectedJointLabel.Parent=panel.pages.Joints
selectedLabel:GetPropertyChangedSignal('Text'):Connect(function() selectedJointLabel.Text=selectedLabel.Text end)
status.Visible=false
status:GetPropertyChangedSignal('Text'):Connect(function() panel:setStatus(if status.Text=='' then 'Ready.' else status.Text) end)
ghostStatus:GetPropertyChangedSignal('Text'):Connect(function() panel:setStatus(ghostStatus.Text) end)
panel:setStatus('Select a rig or joint to begin.')
local alignTabs=Instance.new('Frame'); alignTabs.Name='AlignmentTabs'; alignTabs.Size=UDim2.new(1,0,0,38)
alignTabs.BackgroundTransparency=1; alignTabs.LayoutOrder=1; alignTabs.Parent=panel.pages.Alignment
local feetCard=panel:section('Alignment','Feet','Inspect scene contact and try an experimental, unsaved alignment on the ghost.')
feetCard.LayoutOrder=2
local bodyCard=panel:section('Alignment','Body','Body support, tilt and height alignment are not available yet. These settings will require an actor and valid support contacts.')
bodyCard.LayoutOrder=2; bodyCard.Visible=false
surfacePanel=panel:contactProbe(function(options)
    if not ghost or not surfaceSource or not checkGhostResources() or not ghostGuard or not ghostGuard:check() then
        if surfacePanel then surfacePanel:setResult('Start a viewport simulation for a saved chain before checking contact.') end
        return
    end
    if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
    if poseQueue then poseQueue:cancel() end
    ghostDesiredOrientation=nil; pendingTarget=nil
    surfaceSnapshot=nil
    local origin=ghost:startTarget()
    local ray=require(script.SurfaceProbe).new(workspace,surfaceSource,{ghostWorld})
    local ok,result=pcall(function()
        return require(script.SurfaceContact).probe({origin={origin.X,origin.Y,origin.Z},direction={0,-1,0},up={0,1,0},distance=options.distance,maxSlopeDegrees=options.maxSlopeDegrees,soleOffset=options.soleOffset,supporting=false},function(start,delta)
            return ray:cast(start,delta)
        end)
    end)
    ray:destroy()
    if not ok then surfacePanel:setResult('Contact check failed: '..tostring(result)); return end
    if result.status=='contact' then
        local p,n,t=result.position,result.normal,result.target
        local shown,showError=pcall(function()
            surfaceGuide=require(script.SurfaceContactGizmo).new(ghostWorld)
            surfaceGuide:update({status='contact',position=Vector3.new(p[1],p[2],p[3]),normal=Vector3.new(n[1],n[2],n[3])})
        end)
        if not shown then
            if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
            surfacePanel:setResult('Contact was detected, but its guide could not be shown: '..tostring(showError)); return
        end
        surfaceSnapshot=result
        surfacePanel:setResult(string.format('Surface detected · slope %.1f°\nCandidate: %.2f, %.2f, %.2f studs\nContact does not establish support.',result.slopeDegrees,t[1],t[2],t[3]))
    elseif result.status=='excluded slope' then
        surfacePanel:setResult(string.format('Surface excluded: %.1f° exceeds the maximum slope.',result.slopeDegrees))
    elseif result.status=='no contact' then surfacePanel:setResult('No surface found within the probe distance.')
    else surfacePanel:setResult('Contact result was invalid.') end
end,function(options)
    if not ghost or not surfaceSnapshot or not checkGhostResources() or not ghostGuard or not ghostGuard:check() then
        if surfacePanel then surfacePanel:setResult('Check the scene surface before previewing alignment.') end; return
    end
    if ghostJointCount>16 then surfacePanel:setResult('Alignment preview supports up to 16 joints to keep Studio responsive.'); return end
    local u,f,n=options.soleUp,options.soleForward,surfaceSnapshot.normal
    local aligned,reason=require(script.SurfaceOrientation).align(ghost:startOrientation(),Vector3.new(u[1],u[2],u[3]),Vector3.new(f[1],f[2],f[3]),Vector3.new(n[1],n[2],n[3]),options.strength,require(script.SurfaceFrame))
    if not aligned then surfacePanel:setResult('Cannot determine the surface frame: '..tostring(reason)); return end
    local t=surfaceSnapshot.target; local target=Vector3.new(t[1],t[2],t[3])
    ghostDesiredOrientation=aligned.rotation; previewFallback=aligned.usedFallback
    pendingTarget=nil; ghostTarget:setPosition(target); ghostOffset.Text=ChainDiscovery.formatOffset(target-ghost:startTarget())
    poseQueue:request(target,ghostDesiredOrientation)
    surfacePanel:setResult('Solving ghost alignment; preview assumes support.')
end)
surfacePanel.root.LayoutOrder=3; surfacePanel.root.Parent=feetCard
for _,field in ipairs({surfacePanel.distance,surfacePanel.slope,surfacePanel.soleOffset,surfacePanel.soleUp,surfacePanel.soleForward,surfacePanel.strength}) do
    field:GetPropertyChangedSignal('Text'):Connect(function()
        if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
        if ghostDesiredOrientation then ghostStatus.Text='Alignment preview stopped because settings changed.' end
        surfaceSnapshot=nil; ghostDesiredOrientation=nil
        if poseQueue then poseQueue:cancel() end
    end)
end
local feetTab=Instance.new('TextButton'); feetTab.Name='FeetTab'; feetTab.Text='Feet'; feetTab.Size=UDim2.new(.5,-2,1,0); feetTab.Parent=alignTabs
local bodyTab=Instance.new('TextButton'); bodyTab.Name='BodyTab'; bodyTab.Text='Body'; bodyTab.Position=UDim2.new(.5,2,0,0); bodyTab.Size=UDim2.new(.5,-2,1,0); bodyTab.Parent=alignTabs
local function selectAlignment(feet)
    feetCard.Visible=feet; bodyCard.Visible=not feet
    for _,tab in ipairs({feetTab,bodyTab}) do
        local active=(tab==feetTab)==feet
        tab.BackgroundColor3=if active then Color3.fromRGB(43,102,110) else Color3.fromRGB(49,55,66)
        tab.TextColor3=Color3.fromRGB(240,242,247); tab.Font=Enum.Font.SourceSansBold; tab.TextSize=16
    end
end
feetTab.Activated:Connect(function() selectAlignment(true) end)
bodyTab.Activated:Connect(function() selectAlignment(false) end)
selectAlignment(true)
local simulateLink=Instance.new('TextButton'); simulateLink.Name='OpenSimulate'; simulateLink.Text='Open simulation'
simulateLink.Size=UDim2.fromScale(1,1); simulateLink.BackgroundColor3=Color3.fromRGB(42,115,151)
simulateLink.TextColor3=Color3.new(1,1,1); simulateLink.Font=Enum.Font.SourceSansBold; simulateLink.TextSize=16
simulateLink.Parent=panel.actions; simulateLink.Activated:Connect(function() panel:select('Simulate') end)
root:Destroy(); panel.root.Visible=true
-- Studio may restore an already-open dock widget across a plugin reload.
refresh(); syncVisualSelection(); button:SetActive(widget.Enabled)
