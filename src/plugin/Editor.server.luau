--!strict
-- Authoring prototype only: stores metadata, does not run IK or alter poses.
local Selection = game:GetService('Selection')
local ChangeHistoryService = game:GetService('ChangeHistoryService')
local Config = require(script.Config)
local Builder = require(script.DefinitionBuilder).new(Config)
local toolbar = plugin:CreateToolbar('EditRig IK')
local button = toolbar:CreateButton('Joint Limits', 'Edit IK limit metadata', '')
local widget = plugin:CreateDockWidgetPluginGui('EditRigIKJointLimits', DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 320, 430, 260, 350))
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
    item.Parent = root
    return item
end
local selectedLabel = label('Select one Motor6D or Bone in Explorer.', 38)
local notice = label('Prototype: saves metadata only. Limits do not affect animation or IK yet.', 42)
notice.TextColor3 = Color3.fromRGB(255, 204, 111)
local fields: {[string]: TextBox} = {}
for _, entry in ipairs({{'kind','Type: Hinge or Ball'}, {'axis','Local axis: X, Y or Z'}, {'lower','Lower angle (degrees)'}, {'upper','Upper angle (degrees)'}, {'swing','Ball swing angle (degrees)'}}) do
    local box = Instance.new('TextBox')
    box.Size = UDim2.new(1, 0, 0, 28)
    box.BackgroundColor3 = Color3.fromRGB(60, 63, 72)
    box.TextColor3 = Color3.fromRGB(245, 245, 245)
    box.PlaceholderColor3 = Color3.fromRGB(185, 185, 190)
    box.PlaceholderText = entry[2]
    box.Text = ''
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.SourceSans
    box.TextSize = 16
    box.Parent = root
    fields[entry[1]] = box
end
local apply = Instance.new('TextButton')
apply.Size = UDim2.new(1, 0, 0, 32)
apply.BackgroundColor3 = Color3.fromRGB(61, 109, 172)
apply.TextColor3 = Color3.new(1,1,1)
apply.Text = 'Save limit metadata'
apply.Font = Enum.Font.SourceSansBold
apply.TextSize = 16
apply.Parent = root
local createActor = Instance.new('TextButton')
createActor.Size = UDim2.new(1, 0, 0, 32)
createActor.BackgroundColor3 = Color3.fromRGB(61, 109, 172)
createActor.TextColor3 = Color3.new(1,1,1)
createActor.Text = 'Create direct-control actor from selected model'
createActor.Font = Enum.Font.SourceSansBold
createActor.TextSize = 15
createActor.TextWrapped = true
createActor.Parent = root
local status = label('', 65)
local current: Instance? = nil
local attrs = {kind='EditRigIK_Kind', axis='EditRigIK_Axis', lower='EditRigIK_LowerDegrees', upper='EditRigIK_UpperDegrees', swing='EditRigIK_SwingDegrees'}
local defaults = {kind='Hinge', axis='X', lower=-90, upper=90, swing=90}
local function refresh()
    local items = Selection:Get()
    local item = if #items == 1 then items[1] else nil
    if item and (item:IsA('Motor6D') or item:IsA('Bone')) then
        current = item
        selectedLabel.Text = item.ClassName .. ': ' .. item:GetFullName()
        for key, box in pairs(fields) do
            local value = item:GetAttribute(attrs[key])
            box.Text = tostring(if value ~= nil then value else defaults[key])
        end
        status.Text = ''
    else
        current = nil
        selectedLabel.Text = 'Select exactly one Motor6D or Bone in Explorer.'
        status.Text = ''
    end
end
button.Click:Connect(function() widget.Enabled = not widget.Enabled; button:SetActive(widget.Enabled); if widget.Enabled then refresh() end end)
widget:GetPropertyChangedSignal('Enabled'):Connect(function() button:SetActive(widget.Enabled) end)
Selection.SelectionChanged:Connect(refresh)
apply.MouseButton1Click:Connect(function()
    local item = current
    if not item or not item.Parent then status.Text = 'Select a valid joint first.'; return end
    local ok, result = pcall(Config.validate, {kind=fields.kind.Text, axis=string.upper(fields.axis.Text), lower=tonumber(fields.lower.Text), upper=tonumber(fields.upper.Text), swing=tonumber(fields.swing.Text)})
    if not ok then status.Text = 'Invalid settings: ' .. tostring(result); return end
    ChangeHistoryService:SetWaypoint('Before EditRig IK limit metadata')
    for key, name in pairs(attrs) do item:SetAttribute(name, result[key]) end
    item:SetAttribute('EditRigIK_SchemaVersion', 1)
    ChangeHistoryService:SetWaypoint('Save EditRig IK limit metadata')
    status.Text = 'Saved to ' .. item.Name .. '. Recreate the actor definition to include changes.'
end)

createActor.MouseButton1Click:Connect(function()
    local selection=Selection:Get()
    local model=if #selection==1 then selection[1] else nil
    if not model or not model:IsA('Model') then status.Text='Select one model in Explorer to create an actor.'; return end
    if model:FindFirstChild('EditRigIKActor') or model:FindFirstChild('EditRigIKController') then
        status.Text='Actor or controller already exists. Remove or rename the existing objects before creating another.'; return
    end
    local ok,definition=pcall(Builder.create,model)
    if not ok then status.Text='Cannot create actor: '..tostring(definition); return end
    local controller=script.GeneratedController:Clone()
    controller.Name='EditRigIKController'
    ChangeHistoryService:SetWaypoint('Before create EditRig IK actor')
    definition.Parent=model
    controller.Parent=model
    ChangeHistoryService:SetWaypoint('Create EditRig IK actor')
    status.Text='Created idle direct-control actor. Install the runtime and start it explicitly from a script.'
end)
