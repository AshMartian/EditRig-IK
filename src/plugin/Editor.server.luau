--!strict
-- Studio entry point: creates the panel and connects selection, buttons, and previews.
-- Limit edits stay in a draft until saved; this script owns the viewport helpers
-- and closes them when the widget closes, Play begins, or the plugin unloads.
-- See docs/code-tour.md for the other files involved in each operation.
local Selection = game:GetService('Selection')
local ChangeHistoryService = game:GetService('ChangeHistoryService')
local RunService = game:GetService('RunService')
local Config = require(script.Config)
local LimitFrame = require(script.LimitFrame)
local CircularDraft = require(script.CircularDraft)
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
local syncViewportOwnership = function(_model, _joint) end
local updateChainPath = function(_chain, _selected) end
local getChainOptions = function(_model) return nil,nil,nil end
local viewportPolicy = require(script.ViewportInputPolicy).new()
local LimitGeometry = require(script.LimitGeometry).new(Config)
local LimitDraft = require(script.LimitDraft).new(Config)
local RuntimeInstaller = require(script.RuntimeInstaller)
local InputProfileBuilder = require(script.InputProfileBuilder)
local GaitExampleInstaller = require(script.GaitExampleInstaller)
local JointBatch = require(script.JointBatch)
local JointAuthoring = require(script.JointAuthoring)
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
-- Rig overlay lifetime: the editor creates and disposes the guides, while
-- OverlaySelection decides whether the current selection should show them.
local rigOverlay,overlayFolder,overlayModel,savedLimitOverlay,savedLimitFolder=nil,nil,nil,nil,nil
local savedLimitStatus=''
local function hideRigOverlay()
    updateChainPath(nil,nil)
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
        return RigOverlay.new(model,folder,function(joint)
            Selection:Set({joint})
            if panel then panel:select('Joints') end
        end,ChainInference)
    end)
    if not ok then folder:Destroy(); overlayStatus.Text='Cannot show joints: '..tostring(result); return end
    overlayFolder=folder; rigOverlay=result; overlayModel=model
    rigOverlay:setChainOptions(getChainOptions(model))
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
    if rigOverlay then overlayPolicy:hideOverlay(); hideRigOverlay(); syncVisualSelection(); overlayStatus.Text='3D joints hidden until selection changes or the panel reopens.'; return end
    overlayPolicy:showOverlay(); syncVisualSelection()
end)
local lastOverlayEdit=RunService:IsEdit()
local overlayUpdate=RunService.Heartbeat:Connect(function()
    local edit=RunService:IsEdit()
    if edit~=lastOverlayEdit then lastOverlayEdit=edit; syncVisualSelection() end
    if rigOverlay then
        if not edit or not overlayModel:IsDescendantOf(workspace) then
            if edit then overlayPolicy:hideOverlay() end
            hideRigOverlay(); syncVisualSelection(); overlayStatus.Text='3D joints hidden.'; return
        end
        local items=Selection:Get(); local selected=if #items==1 then items[1] else nil
        rigOverlay:setChainOptions(getChainOptions(overlayModel))
        local ok=pcall(function() rigOverlay:update(selected) end)
        if not ok then overlayPolicy:hideOverlay(); hideRigOverlay(); syncVisualSelection(); overlayStatus.Text='3D joints hidden after an update error.'
        elseif rigOverlay then updateChainPath(rigOverlay:chainState(),selected) end
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
local axisPresetButtons={}
local rangeShiftButtons={}
local rangeShiftFeedback: TextLabel?=nil
local circularNotice: TextLabel?=nil
local replaceCircularButton: TextButton?=nil
local apply = Instance.new('TextButton')
apply.Name='SaveJointLimits'
apply.Size = UDim2.new(1, 0, 0, 32)
apply.BackgroundColor3 = Color3.fromRGB(61, 109, 172)
apply.TextColor3 = Color3.new(1,1,1)
apply.Text = 'Save joint limits'
apply.Font = Enum.Font.SourceSansBold
apply.TextSize = 16
for _, entry in ipairs({{'kind','Limit type'}, {'axis','Local axis'}, {'lower','Lower angle (degrees)'}, {'upper','Upper angle (degrees)'}, {'swing','Ball swing (degrees)'}, {'weight','IK joint influence (0–1)'}, {'control','Control name'}, {'impulse','Impulse name'}, {'frequency','Impulse damping (1/s)'}, {'holdKey','Hold KeyCode (optional)'}, {'reverseHoldKey','Reverse hold KeyCode (optional)'}, {'holdValue','Hold value'}, {'impulseKey','Impulse KeyCode (optional)'}, {'impulseValue','Impulse value (rad/s)'}}) do
    if entry[1]=='control' then label('Control and input settings use the saved joint type.',32) end
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
    if entry[1]=='axis' then
        local note=label('Local hinge axis presets · the rotation plane is perpendicular to the selected axis. Draft only; save to apply.',42)
        note.TextColor3=Color3.fromRGB(192,201,215)
        note.AutomaticSize=Enum.AutomaticSize.Y; note.TextYAlignment=Enum.TextYAlignment.Top
        local choices=Instance.new('Frame')
        choices.Name='LocalAxisPresets'; choices.Size=UDim2.new(1,0,0,32); choices.BackgroundTransparency=1
        order(choices); choices.Parent=root
        for index,axis in ipairs({'X','Y','Z'}) do
            local preset=Instance.new('TextButton')
            preset.Name='LocalAxis'..axis
            preset.Position=UDim2.new((index-1)/3,0,0,0)
            preset.Size=UDim2.new(1/3,-4,1,0)
            preset.BorderSizePixel=0; preset.Font=Enum.Font.SourceSansBold; preset.TextSize=16
            preset.TextColor3=Color3.fromRGB(240,242,247); preset.Parent=choices
            preset.Activated:Connect(function() fields.axis.Text=axis end)
            axisPresetButtons[axis]=preset
        end
    end
    if entry[1]=='upper' then
        circularNotice=label('',30)
        circularNotice.AutomaticSize=Enum.AutomaticSize.Y; circularNotice.TextYAlignment=Enum.TextYAlignment.Top
        circularNotice.TextColor3=Color3.fromRGB(255,204,111)
        replaceCircularButton=Instance.new('TextButton'); replaceCircularButton.Name='ReplaceCircularRange'
        replaceCircularButton.Size=UDim2.new(1,0,0,32); replaceCircularButton.BackgroundColor3=Color3.fromRGB(49,55,66)
        replaceCircularButton.TextColor3=Color3.new(1,1,1); replaceCircularButton.Text='Replace with linear −90° to 90°'
        replaceCircularButton.Font=Enum.Font.SourceSansBold; replaceCircularButton.TextSize=16
        replaceCircularButton.Visible=false; order(replaceCircularButton); replaceCircularButton.Parent=root
        local note=label('Rotate hinge range · shifts both bounds by 5° without changing its width. Draft only.',34)
        note.AutomaticSize=Enum.AutomaticSize.Y; note.TextYAlignment=Enum.TextYAlignment.Top
        note.TextColor3=Color3.fromRGB(192,201,215)
        local choices=Instance.new('Frame')
        choices.Name='HingeRangeRotation'; choices.Size=UDim2.new(1,0,0,32); choices.BackgroundTransparency=1
        order(choices); choices.Parent=root
        for index,step in ipairs({-5,5}) do
            local preset=Instance.new('TextButton')
            preset.Name=if step<0 then 'RotateRangeNegative' else 'RotateRangePositive'
            preset.Position=UDim2.new((index-1)/2,0,0,0); preset.Size=UDim2.new(.5,-4,1,0)
            preset.BorderSizePixel=0; preset.Font=Enum.Font.SourceSansBold; preset.TextSize=16
            preset.TextColor3=Color3.fromRGB(240,242,247); preset.BackgroundColor3=Color3.fromRGB(49,55,66)
            preset.Text=if step<0 then 'Rotate −5°' else 'Rotate +5°'; preset.Parent=choices
            rangeShiftButtons[step]=preset
        end
        rangeShiftFeedback=label('',20)
        rangeShiftFeedback.AutomaticSize=Enum.AutomaticSize.Y; rangeShiftFeedback.TextYAlignment=Enum.TextYAlignment.Top
        rangeShiftFeedback.TextColor3=Color3.fromRGB(255,204,111)
    end
    if entry[1]=='weight' then order(apply); apply.Parent=root end
end
local function updateAxisPresets()
    local selected=string.upper(fields.axis.Text)
    for axis,preset in pairs(axisPresetButtons) do
        local active=axis==selected
        preset.Text=(if active then '● ' else '○ ')..axis
        preset.BackgroundColor3=if active then Color3.fromRGB(43,102,110) else Color3.fromRGB(49,55,66)
    end
end
fields.axis:GetPropertyChangedSignal('Text'):Connect(updateAxisPresets)
updateAxisPresets()
label('Hinge hold: -1 to 1. Ball hold: radians on the selected axis. Impulse: rad/s.',40)
local saveControls=Instance.new('TextButton')
saveControls.Name='SaveJointControls'
saveControls.Size=UDim2.new(1,0,0,32); saveControls.BackgroundColor3=Color3.fromRGB(61,109,172)
saveControls.TextColor3=Color3.new(1,1,1); saveControls.Text='Save control and input settings'
saveControls.Font=Enum.Font.SourceSansBold; saveControls.TextSize=16; order(saveControls); saveControls.Parent=root
local applyBatch=Instance.new('TextButton')
applyBatch.Size=UDim2.new(1,0,0,32); applyBatch.BackgroundColor3=Color3.fromRGB(61,109,172)
applyBatch.TextColor3=Color3.new(1,1,1); applyBatch.Text='Apply limits and controls to selected joints'
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
local draftCircular,baselineCircular=nil,nil
local replaceCircularDraft=false
local updatingFields=false
local limitDiscardNotice=false
local attributeConnection: RBXScriptConnection?=nil
local limitExamplePreview=false
local hingeHandles,hingeFolder,hingeJoint=nil,nil,nil
local hingeActive=false
local viewportOwned=false
local pendingViewportRelease=0
local commitLimitFields=function() end
local setCircularDraft,updateLimitState,updateLimitPreview,limitInput
local hingeButton=Instance.new('TextButton')
hingeButton.Name='EditHingeLimits3D'
hingeButton.Size=UDim2.new(1,0,0,32); hingeButton.BackgroundColor3=Color3.fromRGB(61,109,172)
hingeButton.TextColor3=Color3.new(1,1,1); hingeButton.Text='Resume 3D joint editing'
hingeButton.Font=Enum.Font.SourceSansBold; hingeButton.TextSize=16; order(hingeButton); hingeButton.Parent=root
local limitBinding=PanelComponents.bindLimitInputs({lower=fields.lower,upper=fields.upper,swing=fields.swing,weight=fields.weight},function(key)
    if hingeHandles then hingeHandles:select(if key=='lower' or key=='upper' then key else nil) end
end,function(_,context) if context and context.joint then commitLimitFields(context.joint) else status.Text='Select a valid joint before editing limits.' end end,function()
    return {joint=current,circular=if draftCircular then {start=draftCircular.start,width=draftCircular.width} else nil,lower=fields.lower.Text,upper=fields.upper.Text,replace=replaceCircularDraft}
end,function(key,context,original)
    local selected=Selection:Get()
    if not context or context.joint~=current or #selected~=1 or selected[1]~=current then return end
    updatingFields=true; setCircularDraft(context.circular); replaceCircularDraft=context.replace
    fields.lower.Text=context.lower; fields.upper.Text=context.upper
    if key~='lower' and key~='upper' then fields[key].Text=original end
    updatingFields=false; updateLimitState(); updateLimitPreview()
    if hingeHandles then hingeHandles:sync(current,limitInput()) end
end)
local function stopHingeEdit(message)
    if not hingeActive then return end
    hingeActive=false
    if hingeHandles then hingeHandles:destroy(); hingeHandles=nil end
    if hingeFolder then hingeFolder:Destroy(); hingeFolder=nil end
    hingeJoint=nil
    hingeButton.Text=if viewportOwned then 'Pause 3D joint editing' else 'Resume 3D joint editing'
    if message then status.Text=message end
end
local function releaseViewport()
    if not viewportOwned then return end
    viewportOwned=false
    hingeButton.Text='Resume 3D joint editing'
    -- Another Studio tool may already have deactivated us while its event is
    -- deferred. Do not count a release that cannot emit our own event.
    if not plugin:IsActivated() then return end
    pendingViewportRelease+=1
    local ok=pcall(function() plugin:Deactivate() end)
    if not ok then pendingViewportRelease-=1 end
end
limitInput=function()
    return {kind=fields.kind.Text,axis=string.upper(fields.axis.Text),lower=tonumber(fields.lower.Text),upper=tonumber(fields.upper.Text),swing=tonumber(fields.swing.Text),weight=tonumber(fields.weight.Text) or fields.weight.Text,circular=draftCircular,replaceCircular=replaceCircularDraft}
end
local function rememberLimitFields()
    for _,key in ipairs(limitKeys) do baseline[key]=fields[key].Text end
    baselineCircular=if draftCircular then {start=draftCircular.start,width=draftCircular.width} else nil
end
local function limitFieldsChanged(): boolean
    for _,key in ipairs(limitKeys) do if baseline[key]~=fields[key].Text then return true end end
    if (baselineCircular==nil)~=(draftCircular==nil) then return true end
    if baselineCircular and (baselineCircular.start~=draftCircular.start or baselineCircular.width~=draftCircular.width) then return true end
    return false
end
setCircularDraft=function(interval)
    draftCircular=if interval then {start=interval.start,width=interval.width} else nil
    if circularNotice then
        circularNotice.Text=if draftCircular and type(draftCircular.width)=='number' then string.format('Circular hinge · %.1f° allowed. Works with custom IK chains; direct actors and built-in constraints do not yet support it.',draftCircular.width) elseif draftCircular then 'Circular hinge metadata is incomplete; review it before saving.' else ''
    end
    if replaceCircularButton then replaceCircularButton.Visible=draftCircular~=nil end
end
for _,key in ipairs({'lower','upper'}) do
    fields[key]:GetPropertyChangedSignal('Text'):Connect(function()
        if updatingFields or not draftCircular then return end
        local value=tonumber(fields[key].Text)
        local ok,interval=pcall(CircularDraft.setBound,draftCircular,key,value)
        if ok then setCircularDraft(interval) end
    end)
end
updateLimitState=function()
    if updatingFields then return end
    local state=LimitDraft.classify(current,limitInput(),limitExamplePreview or limitFieldsChanged())
    local messages={
        none='Limit settings: select one joint.',
        unconfigured='Unconfigured: example values are not saved. The limit guide is hidden until configured.',
        saved='Saved limit settings. Yellow guide shows the saved values.',
        draft='Unsaved limit changes. Yellow guide shows the draft.',
        invalid='Invalid limit input. Yellow guide is hidden; nothing was saved.',
        invalidSaved='Saved limit metadata is incomplete, invalid or unsupported. Review and save.',
    }
    limitStateLabel.Text=messages[state] or 'Limit state unavailable.'
    if state=='draft' and current and current:GetAttribute('EditRigIK_SchemaVersion')==nil then
        limitStateLabel.Text=if limitFieldsChanged() then 'Unconfigured joint: unsaved limit edits. Save joint limits to apply.' else 'Example limits, not saved. Save joint limits to apply.'
    end
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
updateLimitPreview=function()
    if updatingFields then return end
    if not axisGizmo then return end
    local classification=LimitDraft.classify(current,limitInput(),limitExamplePreview or limitFieldsChanged())
    -- Blank/invalid metadata never renders the numeric form's fallback values
    -- as if they were an authored limit.
    axisGizmo:setLimits(if OverlaySelection.showLimit(classification) then limitInput() else nil)
end
replaceCircularButton.Activated:Connect(function()
    if not draftCircular or not current then return end
    updatingFields=true; setCircularDraft(nil); replaceCircularDraft=true
    fields.lower.Text='-90'; fields.upper.Text='90'; updatingFields=false
    updateLimitState(); updateLimitPreview()
    if hingeHandles then hingeHandles:sync(current,limitInput()) end
    status.Text='Replaced with a linear −90° to 90° draft. Save joint limits to apply.'
end)
for _,key in ipairs(limitKeys) do
    fields[key]:GetPropertyChangedSignal('Text'):Connect(updateLimitPreview)
    fields[key]:GetPropertyChangedSignal('Text'):Connect(function()
        if updatingFields then return end
        if hingeHandles then hingeHandles:sync(current,limitInput())
        elseif current then task.defer(function() if current then syncVisualSelection() end end) end
    end)
end
for step,button in pairs(rangeShiftButtons) do
    button.Activated:Connect(function()
        local selected=Selection:Get()
        if not current or #selected~=1 or selected[1]~=current then
            rangeShiftFeedback.Text='Select one joint before rotating its range.'; return
        end
        if fields.kind.Text~='Hinge' then
            rangeShiftFeedback.Text='Range rotation is available for hinge limits.'; return
        end
        if draftCircular then
            local ok,shifted=pcall(CircularDraft.shift,draftCircular,step)
            if not ok then rangeShiftFeedback.Text='Enter a valid circular hinge range first.'; return end
            updatingFields=true; setCircularDraft(shifted)
            fields.lower.Text=tostring(shifted.start); fields.upper.Text=tostring(CircularDraft.endpoint(shifted))
            updatingFields=false
            updateLimitState(); updateLimitPreview()
            if hingeHandles then hingeHandles:sync(current,limitInput()) end
            rangeShiftFeedback.Text='Range rotated by '..tostring(step)..'°. Unsaved draft; save joint limits to apply.'; return
        end
        local lower,upper=tonumber(fields.lower.Text),tonumber(fields.upper.Text)
        local ok,shifted=pcall(function() return LimitFrame.shiftInterval(math.rad(lower),math.rad(upper),math.rad(step)) end)
        if not ok then
            rangeShiftFeedback.Text='Enter a valid lower and upper angle from −180° to 180° first.'; return
        end
        if shifted.full then
            rangeShiftFeedback.Text='A full 360° range is unchanged by rotation.'; return
        end
        -- A wrapping interval cannot be represented by the current solver.
        -- Check the unwrapped values too: a complete turn across the seam
        -- can yield a non-wrapping normalized interval after crossing 180°.
        local nextLower,nextUpper=lower+step,upper+step
        if nextLower < -180 or nextUpper > 180 or (shifted.wraps and nextUpper < 180-1e-9) then
            local interval={start=(nextLower+180)%360-180,width=upper-lower}
            updatingFields=true; setCircularDraft(interval)
            fields.lower.Text=tostring(interval.start); fields.upper.Text=tostring(CircularDraft.endpoint(interval))
            updatingFields=false
            updateLimitState(); updateLimitPreview()
            if hingeHandles then hingeHandles:sync(current,limitInput()) end
            rangeShiftFeedback.Text='Range rotated across ±180°. Unsaved draft; save joint limits to apply.'; return
        end
        updatingFields=true
        fields.lower.Text=tostring(nextLower); fields.upper.Text=tostring(nextUpper)
        updatingFields=false
        updateLimitState(); updateLimitPreview()
        if hingeHandles then hingeHandles:sync(current,limitInput()) end
        rangeShiftFeedback.Text='Range rotated by '..tostring(step)..'°. Unsaved draft; save joint limits to apply.'
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
    status.Text='X red, Y green, Z blue; yellow shows hinge range or ball swing, orange shows ball twist.'
end
axisButton.MouseButton1Click:Connect(function()
    if axisGizmo then stopHingeEdit(nil); overlayPolicy:hideAxes(); hideAxes(); syncVisualSelection(); status.Text='Joint guide hidden until selection changes or the panel reopens.'; return end
    overlayPolicy:showAxes(); syncVisualSelection()
end)
local function startHingeEdit()
    if hingeActive or not viewportOwned or not widget.Enabled or not RunService:IsEdit() or not current then return end
    if not current:IsDescendantOf(workspace) then return end
    local ok,config=pcall(Config.validate,limitInput())
    if not ok or config.kind~='Hinge' then return end
    local state=LimitDraft.classify(current,limitInput())
    if state=='invalidSaved' then return end
    limitExamplePreview=state=='unconfigured' or limitExamplePreview
    updateLimitState(); updateLimitPreview()
    local folder=Instance.new('Folder'); folder.Name='EditRigIKHingeHandles'; folder.Parent=game:GetService('CoreGui')
    local joint=current
    local created,handles=pcall(function()
        return HingeLimitHandles.new(folder,plugin:GetMouse(),Config,HingeDragMath,AxisGizmo.restFrame,function(bound,value,interval,restoreLegacy)
            if hingeActive and current==joint then
                limitBinding:select(bound)
                if interval or restoreLegacy then
                    updatingFields=true; setCircularDraft(interval)
                    if restoreLegacy then fields.lower.Text=tostring(restoreLegacy.lower); fields.upper.Text=tostring(restoreLegacy.upper)
                    else fields.lower.Text=tostring(interval.start); fields.upper.Text=tostring(CircularDraft.endpoint(interval)) end
                    updatingFields=false
                    updateLimitState(); updateLimitPreview()
                else limitBinding:setValue(bound,value) end
            end
        end,function(bound)
            limitBinding:select(bound)
            if panel then
                panel:select('Joints')
                local page=panel.pages.Joints
                local row=fields[bound].Parent
                page.CanvasPosition=Vector2.new(0,math.max(0,page.CanvasPosition.Y+row.AbsolutePosition.Y-page.AbsolutePosition.Y-45))
            end
            status.Text='Drag the '..bound..' handle; changes are unsaved until you choose Save joint limits.'
        end)
    end)
    if not created then folder:Destroy(); status.Text='Cannot create hinge handles: '..tostring(handles); return end
    hingeFolder=folder; hingeHandles=handles; hingeJoint=joint
    if not hingeHandles:set(joint,limitInput()) then hingeHandles:destroy(); hingeHandles=nil; folder:Destroy(); hingeFolder=nil; status.Text='Cannot display this joint frame.'; return end
    hingeActive=true; hingeButton.Text='Pause 3D joint editing'
    status.Text='Drag an axis-colored endpoint to edit its draft limit. Press Escape to cancel a drag; save to apply.'
end
hingeButton.Activated:Connect(function()
    if viewportOwned then
        viewportPolicy:toolTakenOver(); stopHingeEdit('3D joint editing paused; draft values remain unsaved.'); releaseViewport()
    else
        viewportPolicy:resume(); overlayPolicy:showOverlay(); overlayPolicy:showAxes(); syncVisualSelection()
    end
end)
plugin.Deactivation:Connect(function()
    if pendingViewportRelease>0 then pendingViewportRelease-=1; return end
    viewportOwned=false; viewportPolicy:toolTakenOver()
    stopHingeEdit('Another Studio tool is active; 3D editing is paused. Draft values remain unsaved.')
    hingeButton.Text='Resume 3D joint editing'
    status.Text='Another Studio tool is active; 3D editing is paused. Draft values remain unsaved.'
end)
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
        if not ok or not visible or not RunService:IsEdit() then
            if RunService:IsEdit() then overlayPolicy:hideAxes() end
            hideAxes(); syncVisualSelection()
        end
    end
end)
plugin.Unloading:Connect(function() stopHingeEdit(nil); releaseViewport(); limitBinding:destroy(); axisUpdate:Disconnect(); hideAxes() end)
local attrs = {kind='EditRigIK_Kind', axis='EditRigIK_Axis', lower='EditRigIK_LowerDegrees', upper='EditRigIK_UpperDegrees', swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
local defaults = {kind='Hinge', axis='X', lower=-90, upper=90, swing=90,weight=1,holdKey='',reverseHoldKey='',holdValue=1,impulseKey='',impulseValue=1}
local driveAttrs = {control='EditRigIK_Control',impulse='EditRigIK_Impulse',frequency='EditRigIK_Frequency'}
local inputAttrs = {holdKey='EditRigIK_HoldKey',reverseHoldKey='EditRigIK_ReverseHoldKey',holdValue='EditRigIK_HoldValue',impulseKey='EditRigIK_ImpulseKey',impulseValue='EditRigIK_ImpulseValue'}
local function refresh()
    local items = Selection:Get()
    local item = if #items == 1 then items[1] else nil
    local discarded=current~=nil and current~=item and (limitFieldsChanged() or LimitDraft.classify(current,limitInput())=='draft')
    if current~=item then stopHingeEdit(nil); limitBinding:abandon(); limitBinding:select(nil); limitExamplePreview=false; rangeShiftFeedback.Text='' end
    if attributeConnection then attributeConnection:Disconnect(); attributeConnection=nil end
    updatingFields=true
    if item and (item:IsA('Motor6D') or item:IsA('Bone')) then
        current = item
        replaceCircularDraft=false
        local start,width=item:GetAttribute('EditRigIK_CircularStartDegrees'),item:GetAttribute('EditRigIK_CircularWidthDegrees')
        setCircularDraft(if item:GetAttribute('EditRigIK_SchemaVersion')==2 then {start=start,width=width} else nil)
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
    if current then attributeConnection=current.AttributeChanged:Connect(function()
        stopHingeEdit(nil); updateLimitState(); updateLimitPreview()
        task.defer(function() if current==item then syncVisualSelection() end end)
    end) end
    updateLimitState()
    updateLimitPreview()
end
syncViewportOwnership=function(model,joint)
    local desired=viewportPolicy:update(widget.Enabled,RunService:IsEdit(),model~=nil or joint~=nil)
    if not desired then stopHingeEdit(nil); releaseViewport(); return end
    if not viewportOwned then
        viewportOwned=true
        local ok,err=pcall(function() plugin:Activate(true) end)
        if not ok then viewportOwned=false; status.Text='Cannot activate 3D joint editing: '..tostring(err); return end
        hingeButton.Text='Pause 3D joint editing'
    end
    if joint and axisGizmo then startHingeEdit() else stopHingeEdit(nil) end
end
-- Reconcile Studio selection, the active panel, and exclusive viewport input.
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
    syncViewportOwnership(if rigOverlay then desiredModel else nil,if axisGizmo then desiredJoint else nil)
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
commitLimitFields=function(expected)
    local item = current
    local selected=Selection:Get()
    if not item or not item.Parent or (expected and item~=expected) or #selected~=1 or selected[1]~=item then status.Text = 'Selection changed; joint limits were not saved.'; return end
    local ok, prepared=pcall(JointAuthoring.prepareLimits,item,limitInput(),Config)
    if not ok then status.Text='Invalid joint limits: '..tostring(prepared); return end
    local saved,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before EditRig IK joint limits')
        JointAuthoring.applyLimits(prepared)
        ChangeHistoryService:SetWaypoint('Save EditRig IK joint limits')
    end)
    if not saved then status.Text='Joint limits not saved: '..tostring(err); return end
    rememberLimitFields(); replaceCircularDraft=false; limitExamplePreview=false; limitDiscardNotice=false; updateLimitState()
    status.Text = if draftCircular then 'Saved circular joint limits to '..item.Name..'. Refresh chain snapshots; direct actors and built-in constraints do not support circular limits yet.' else 'Saved joint limits to ' .. item.Name .. '. Control settings were not changed; review them if the joint type changed. Refresh actor and chain snapshots to use the changes.'
end
apply.MouseButton1Click:Connect(function() commitLimitFields() end)
saveControls.MouseButton1Click:Connect(function()
    local item=current
    if not item or not item.Parent then status.Text='Select a valid joint first.'; return end
    local settings={control=fields.control.Text,impulse=fields.impulse.Text,frequency=tonumber(fields.frequency.Text),
        holdKey=fields.holdKey.Text,reverseHoldKey=fields.reverseHoldKey.Text,holdValue=tonumber(fields.holdValue.Text),
        impulseKey=fields.impulseKey.Text,impulseValue=tonumber(fields.impulseValue.Text)}
    local ok,prepared=pcall(JointAuthoring.prepareDrive,item,settings,Config,InputProfileBuilder)
    if not ok then status.Text='Invalid control or input settings: '..tostring(prepared); return end
    local saved,err=pcall(function()
        ChangeHistoryService:SetWaypoint('Before EditRig IK controls and inputs')
        JointAuthoring.applyDrive(prepared)
        ChangeHistoryService:SetWaypoint('Save EditRig IK controls and inputs')
    end)
    if not saved then status.Text='Control settings not saved: '..tostring(err); return end
    status.Text='Saved control and input settings to '..item.Name..'. Joint limits were not changed. Refresh the actor to use the changes.'
end)
local function batchValues()
    assert(not draftCircular,'batch editing circular hinge ranges is not supported')
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

-- Actor commands copy saved settings into a recipe; they do not start motion.
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
chainStatus.AutomaticSize=Enum.AutomaticSize.Y
chainStatus.TextYAlignment=Enum.TextYAlignment.Top
local chainFeedback: TextLabel
local firstJoint: Instance?=nil
local lastJoint: Instance?=nil
local endpoint: Instance?=nil
local pole: Instance?=nil
local capturedControl: Instance?=nil
local capturedChain: any=nil
local captureModel: Instance?=nil
local rootSource, endSource, endpointSource=nil,nil,nil
-- Chain capture collects explicit choices before creating a saved definition.
local function clearChainCapture()
    firstJoint=nil; lastJoint=nil; endpoint=nil; pole=nil
    capturedControl=nil; capturedChain=nil; captureModel=nil
    rootSource=nil; endSource=nil; endpointSource=nil
end
local function adoptCapture(item: Instance): boolean
    if captureModel and item:IsDescendantOf(captureModel) then return true end
    local model=item:FindFirstAncestorWhichIsA('Model')
    if not model then return false end
    clearChainCapture(); captureModel=model
    return true
end
getChainOptions=function(model)
    if not captureModel or not model or (captureModel~=model and not captureModel:IsDescendantOf(model)) then return nil,nil,nil end
    return if rootSource=='explicit' then firstJoint else nil,
        if endpointSource=='explicit' then endpoint else nil,
        if endSource=='explicit' then lastJoint else nil
end
local function refreshChainStatus()
    local function described(item,source) return if item then item.Name..' ('..(source or 'unknown')..')' else '—' end
    chainStatus.Text='Captured rig: '..(if captureModel then captureModel:GetFullName() else '—')..'\nRoot: '..described(firstJoint,rootSource)..'  |  End: '..described(lastJoint,endSource)..'  |  Endpoint: '..described(endpoint,endpointSource)..'  |  Pole: '..(if pole then pole.Name else 'none')
    if rigOverlay then rigOverlay:setChainOptions(getChainOptions(overlayModel)) end
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
    local sameRig=captureModel~=nil and joint:IsDescendantOf(captureModel)
    local model=if sameRig then captureModel else joint:FindFirstAncestorWhichIsA('Model')
    local options={root=if sameRig and rootSource=='explicit' then firstJoint else nil,endpoint=if sameRig and endpointSource=='explicit' then endpoint else nil}
    local ok,result=pcall(ChainInference.infer,model,joint,options)
    if not ok then inferenceStatus.Text='Cannot infer chain: '..tostring(result)..'. Previous capture is unchanged.'; return end
    if not result.ok then inferenceStatus.Text='Cannot infer chain: '..result.message..' Use the capture buttons below to choose a root, end and endpoint. Previous capture is unchanged.'; return end
    if sameRig and endSource=='explicit' and lastJoint~=result.endJoint then inferenceStatus.Text='The inferred endpoint does not match the explicitly selected end joint. Select the matching endpoint; previous capture is unchanged.'; return end
    if not sameRig then clearChainCapture(); captureModel=model end
    capturedControl=nil; capturedChain=nil; firstJoint=result.root; lastJoint=result.endJoint; endpoint=result.endpoint; pole=nil
    rootSource=result.rootSource; endSource=if sameRig and endSource=='explicit' then 'explicit' else 'inferred'; endpointSource=result.endpointSource
    refreshChainStatus()
    local names={}
    for _,j in ipairs(result.joints) do table.insert(names,j.Name) end
    inferenceStatus.Text='Suggested chain (explicit choices preserved; remaining choices inferred): '..table.concat(names,' → ')..'  |  Endpoint: '..result.endpoint.Name..'. Review and correct with the capture buttons below; no limits or chain were saved.'
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
    if not ok then clearChainCapture(); refreshChainStatus(); chainFeedback.Text='Cannot discover chain: '..tostring(result); return end
    if not adoptCapture(result.joints[1]) then chainFeedback.Text='Captured joints must belong to a model.'; return end
    capturedControl=item; capturedChain=result
    firstJoint=result.joints[1]; lastJoint=result.joints[#result.joints]
    endpoint=result.endpoint; pole=result.pole
    rootSource='explicit'; endSource='explicit'; endpointSource=if endpoint then 'explicit' else nil
    chainName.Text=string.sub(item.Name,1,64)
    local missing=0
    for _,joint in ipairs(result.joints) do local version=joint:GetAttribute('EditRigIK_SchemaVersion'); if version~=1 and version~=2 then missing+=1 end end
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
    if not adoptCapture(item) then chainFeedback.Text='The root joint must belong to a model.'; return end
    capturedControl=nil; capturedChain=nil; firstJoint=item; rootSource='explicit'; refreshChainStatus()
end)
chainButton('Set end joint from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or not (item:IsA('Motor6D') or item:IsA('Bone')) then chainFeedback.Text='Select one Motor6D or Bone as the end.'; return end
    if not adoptCapture(item) then chainFeedback.Text='The end joint must belong to a model.'; return end
    capturedControl=nil; capturedChain=nil; lastJoint=item; endSource='explicit'; refreshChainStatus()
end)
chainButton('Set endpoint attachment from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or item.ClassName~='Attachment' then chainFeedback.Text='Select one regular Attachment as the endpoint.'; return end
    if not adoptCapture(item) then chainFeedback.Text='The endpoint must belong to a model.'; return end
    endpoint=item; endpointSource='explicit'; refreshChainStatus()
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
    endpoint=attachment; endpointSource='explicit'; refreshChainStatus()
    chainFeedback.Text='Endpoint created at the entered offset. Verify its position on the rig.'
end)
chainButton('Set optional pole attachment from selection').MouseButton1Click:Connect(function()
    local item=selectedOne()
    if not item or item.ClassName~='Attachment' then chainFeedback.Text='Select one regular Attachment as the pole.'; return end
    if captureModel and not item:IsDescendantOf(captureModel) then chainFeedback.Text='The pole must belong to the captured rig.'; return end
    pole=item; refreshChainStatus()
end)
chainButton('Clear captured pole').MouseButton1Click:Connect(function()
    pole=nil; refreshChainStatus(); chainFeedback.Text='Pole cleared for the next chain.'
end)
chainButton('Clear captured chain choices').MouseButton1Click:Connect(function()
    clearChainCapture(); refreshChainStatus(); inferenceStatus.Text='Chain choices cleared; the viewport will infer a path from the selected joint.'
    chainFeedback.Text='Captured chain choices cleared.'
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
-- The panel preview owns a disposable clone and never poses the source rig.
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
        local solver=require(script.PreviewSolver).new(require(script.PreviewLimits),require(script.PreviewCircularHinge).v1)
        local adapter=require(script.PreviewChainAdapter)
        local chainDefinition=require(script.PreviewChainDefinition)
        return require(script.PreviewSession).new(definition,previewFrame,{createChain=function(copy)
            return chainDefinition.new(copy,{exclusive=true},function(joints,point,options)
                return adapter.new(joints,point,options,solver)
            end,LimitFrame)
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
local ghostTargetPosition,ghostCurrentOrientation,orientationSource,ghostModeButton=nil,nil,nil,nil
local ghostMode='move'
local pendingTarget=nil
-- The world ghost has a separate lifetime and must release viewport resources.
local function closeGhost()
    pendingTarget=nil
    if poseQueue then poseQueue:cancel(); poseQueue=nil end
    ghostDesiredOrientation=nil; ghostTargetPosition=nil; ghostCurrentOrientation=nil; orientationSource=nil; ghostJointCount=0; surfaceSnapshot=nil; previewFallback=false
    ghostMode='move'; if ghostModeButton then ghostModeButton.Text='Rotate target' end
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
    local schema=definition and definition:GetAttribute('SchemaVersion')
    if not definition or not definition:IsA('Folder') or (schema~=1 and schema~=2 and schema~=3) or not definition.Parent or definition.Parent.Name~='EditRigIKChains' or not definition.Parent.Parent or not definition.Parent.Parent:IsA('Model') then
        ghostStatus.Text='Select a saved chain definition first.'; return
    end
    local ok,result=pcall(function()
        assert(not workspace:FindFirstChild('EditRigIKGhostSession'),'another temporary ghost session already exists')
        ghostWorld=Instance.new('Folder'); ghostWorld.Name='EditRigIKGhostSession'; ghostWorld.Archivable=false
        ghostGui=Instance.new('Folder'); ghostGui.Name='EditRigIKGhostGui'; ghostGui.Archivable=false
        local solver=require(script.PreviewSolver).new(require(script.PreviewLimits),require(script.PreviewCircularHinge).v1)
        local adapter=require(script.PreviewChainAdapter)
        local chainDefinition=require(script.PreviewChainDefinition)
        ghost=require(script.WorldGhostSession).new(definition,ghostWorld,{createChain=function(copy)
            return chainDefinition.new(copy,{exclusive=true},function(joints,point,options)
                return adapter.new(joints,point,options,solver)
            end,LimitFrame)
        end})
        ghostJointCount=#definition.Joints:GetChildren()
        poseQueue=require(script.PosePreviewQueue).new(math.min(40,definition:GetAttribute('Iterations')))
        ghostTargetPosition=ghost:startTarget()
        ghostCurrentOrientation=ghost:startOrientation()
        ghostTarget=require(script.ViewportTargetHandle).new(ghostWorld,ghostGui,ghostTargetPosition,function(target)
            if checkGhostResources() then
                local moved,err=pcall(function()
                    ghostTargetPosition=target
                    ghostTarget:setPosition(target); ghostOffset.Text=ChainDiscovery.formatOffset(target-ghost:startTarget())
                    if ghostDesiredOrientation then poseQueue:request(target,ghostDesiredOrientation) else pendingTarget=target end
                end)
                if not moved then closeGhost(); ghostStatus.Text='Simulation closed after target error: '..tostring(err) end
            end
        end,{orientation=ghost:startOrientation(),onOrientation=function(rotation)
            if checkGhostResources() and ghostGuard and ghostGuard:check() then
                local rotated,err=pcall(function()
                    ghostDesiredOrientation=rotation; orientationSource='manual'; previewFallback=false; pendingTarget=nil
                    surfaceSnapshot=nil
                    if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
                    ghostTarget:setOrientation(rotation)
                    poseQueue:request(ghostTargetPosition,rotation)
                    if surfacePanel then surfacePanel:setResult('Manual target orientation. Check the surface again before aligning.') end
                end)
                if not rotated then closeGhost(); ghostStatus.Text='Simulation closed after orientation error: '..tostring(err) end
            end
        end})
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
ghostModeButton=chainButton('Rotate target')
ghostModeButton.Name='GhostTargetMode'
ghostModeButton.MouseButton1Click:Connect(function()
    if not ghost or not checkGhostResources() or not ghostGuard or not ghostGuard:check() then
        ghostStatus.Text='Start viewport simulation before rotating the target.'; return
    end
    local ok,err=pcall(function()
        ghostMode=if ghostMode=='move' then 'rotate' else 'move'
        if ghostMode=='rotate' then ghostTarget:setOrientation(ghostDesiredOrientation or ghostCurrentOrientation) end
        ghostTarget:setMode(ghostMode)
    end)
    if not ok then closeGhost(); ghostStatus.Text='Simulation closed after target mode error: '..tostring(err); return end
    ghostModeButton.Text=if ghostMode=='rotate' then 'Move target' else 'Rotate target'
    ghostStatus.Text=if ghostMode=='rotate' then 'Drag a local-axis rotation ring to orient the ghost endpoint.' else 'Drag a world-axis arrow to move the ghost target.'
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
        ghostTargetPosition=target
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
    ghostDesiredOrientation=nil; orientationSource=nil; previewFallback=false
    surfaceSnapshot=nil
    if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
    if surfacePanel then surfacePanel:setResult('Preview reset. Check the scene surface again before aligning.') end
    local ok,err=pcall(function() ghost:reset(); local start=ghost:startTarget(); ghostTargetPosition=start; ghostCurrentOrientation=ghost:startOrientation(); ghostTarget:setPosition(start); ghostTarget:setEndpoint(start); ghostTarget:setOrientation(ghostCurrentOrientation) end)
    if not ok then closeGhost(); ghostStatus.Text='Simulation closed after reset error: '..tostring(err); return end
    ghostOffset.Text=ChainDiscovery.formatOffset(Vector3.zero)
    ghostStatus.Text='Preview reset to its starting pose.'
end)
local ghostEndButton=chainButton('End viewport simulation')
ghostEndButton.MouseButton1Click:Connect(function() closeGhost(); ghostStatus.Text='Simulation closed.' end)
local ghostUpdate=RunService.Heartbeat:Connect(function()
    if surfaceGuide and not surfaceGuide:isValid() then
        surfaceGuide:destroy(); surfaceGuide=nil
        surfaceSnapshot=nil
        if orientationSource=='surface' then ghostDesiredOrientation=nil; orientationSource=nil; if poseQueue then poseQueue:cancel() end end
        if surfacePanel then surfacePanel:setResult('Contact guide was removed. Check the scene surface again.') end
    end
    if not ghost or not checkGhostResources() then return end
    if not ghostGuard or not ghostGuard:check() then return end
    local job=poseQueue and poseQueue:next()
    if job then
        local ok,result=pcall(function()
            local solved=ghost:solveTarget(job.target,{iterations=1,targetOrientation=job.orientation,orientationTolerance=math.rad(1)})
            ghostTarget:setEndpoint(solved.endpointWorld); ghostCurrentOrientation=solved.endpointOrientationWorld; return solved
        end)
        if not ok then poseQueue:complete(job,nil); closeGhost(); ghostStatus.Text='Simulation closed after solve error: '..tostring(result); return end
        local accepted,state=poseQueue:complete(job,result)
        if accepted then
            local label=if state=='pending' then 'Solving' elseif state=='converged' then 'Reached' else 'Not reached'
            local message=string.format('%s · gap %.3f studs · orientation error %.1f° · step %d',label,result.error,math.deg(result.orientationError),job.iteration)
            if previewFallback then message..=' · heading fallback' end
            ghostStatus.Text=message
            if surfacePanel and orientationSource=='surface' then surfacePanel:setResult(message..'\nPreview assumes support; original rig is unchanged.') end
        end
        return
    end
    if not pendingTarget then return end
    local target=pendingTarget; pendingTarget=nil
    local ok,result=pcall(function() local solved=ghost:solveTarget(target); ghostTarget:setEndpoint(solved.endpointWorld); ghostCurrentOrientation=solved.endpointOrientationWorld; return solved end)
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
ghostStartButton.LayoutOrder=5; ghostModeButton.LayoutOrder=6; ghostSetTargetButton.LayoutOrder=7; ghostResetButton.LayoutOrder=8; ghostEndButton.LayoutOrder=9
local selectedJointLabel=selectedLabel:Clone()
selectedJointLabel.Name='SelectedJointContext'; selectedJointLabel.LayoutOrder=0; selectedJointLabel.Parent=panel.pages.Joints
selectedLabel:GetPropertyChangedSignal('Text'):Connect(function() selectedJointLabel.Text=selectedLabel.Text end)
local chainPathView=require(script.ChainPathView).new(panel.pages.Joints,function(joint)
    if overlayModel and joint:IsDescendantOf(overlayModel) then Selection:Set({joint}) end
end)
chainPathView.root.LayoutOrder=1
updateChainPath=function(chain,selected) chainPathView:set(chain,selected) end
plugin.Unloading:Connect(function() chainPathView:destroy() end)
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
    if orientationSource=='surface' then
        if poseQueue then poseQueue:cancel() end
        ghostDesiredOrientation=nil; orientationSource=nil
    end
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
    ghostDesiredOrientation=aligned.rotation; orientationSource='surface'; previewFallback=aligned.usedFallback
    pendingTarget=nil; ghostTargetPosition=target; ghostTarget:setPosition(target); ghostTarget:setOrientation(aligned.rotation); ghostOffset.Text=ChainDiscovery.formatOffset(target-ghost:startTarget())
    poseQueue:request(target,ghostDesiredOrientation)
    surfacePanel:setResult('Solving ghost alignment; preview assumes support.')
end)
surfacePanel.root.LayoutOrder=3; surfacePanel.root.Parent=feetCard
for _,field in ipairs({surfacePanel.distance,surfacePanel.slope,surfacePanel.soleOffset,surfacePanel.soleUp,surfacePanel.soleForward,surfacePanel.strength}) do
    field:GetPropertyChangedSignal('Text'):Connect(function()
        if surfaceGuide then surfaceGuide:destroy(); surfaceGuide=nil end
        if orientationSource=='surface' then
            ghostStatus.Text='Alignment preview stopped because settings changed.'
            ghostDesiredOrientation=nil; orientationSource=nil
            if poseQueue then poseQueue:cancel() end
        end
        surfaceSnapshot=nil
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
