--!strict
-- Reusable dock shell. Page content and behavior are supplied by the caller.
local PanelComponents = {}

local colors = {
    background = Color3.fromRGB(28, 31, 38),
    navigation = Color3.fromRGB(36, 40, 49),
    selected = Color3.fromRGB(48, 58, 67),
    card = Color3.fromRGB(38, 42, 51),
    text = Color3.fromRGB(240, 242, 247),
    muted = Color3.fromRGB(192, 201, 215),
    accent = Color3.fromRGB(73, 214, 224),
    warning = Color3.fromRGB(255, 204, 111),
    error = Color3.fromRGB(255, 152, 152),
}

local function textLabel(name: string, text: string, height: number): TextLabel
    local label = Instance.new('TextLabel')
    label.Name = name
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, height)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextColor3 = colors.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = true
    label.Text = text
    return label
end

local function list(parent: Instance, gap: number)
    local layout = Instance.new('UIListLayout')
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, gap)
    layout.Parent = parent
end

local function padding(parent: Instance, amount: number)
    local pad = Instance.new('UIPadding')
    pad.PaddingTop = UDim.new(0, amount)
    pad.PaddingBottom = UDim.new(0, amount)
    pad.PaddingLeft = UDim.new(0, amount)
    pad.PaddingRight = UDim.new(0, amount)
    pad.Parent = parent
end

function PanelComponents.new(parent: Instance)
    local shell = Instance.new('Frame')
    shell.Name = 'EditRigPanel'
    shell.Size = UDim2.fromScale(1, 1)
    shell.BackgroundColor3 = colors.background
    shell.BorderSizePixel = 0
    shell.Parent = parent

    local nav = Instance.new('Frame')
    nav.Name = 'Navigation'
    nav.Size = UDim2.new(1, 0, 0, 48)
    nav.BackgroundColor3 = colors.navigation
    nav.BorderSizePixel = 0
    nav.Parent = shell

    local pages = {}
    local buttons = {}
    local indicators = {}
    local entries = {
        { 'Rig', '◆' }, { 'Joints', '●' },
        { 'Alignment', '▲' }, { 'Simulate', '▶' },
    }
    for index, entry in ipairs(entries) do
        local name, icon = entry[1], entry[2]
        local page = Instance.new('ScrollingFrame')
        page.Name = name .. 'Page'
        page.Position = UDim2.fromOffset(0, 48)
        page.Size = UDim2.new(1, 0, 1, -150)
        page.BackgroundTransparency = 1
        page.ClipsDescendants = true
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 6
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new()
        page.Visible = false
        padding(page, 10)
        list(page, 8)
        page.Parent = shell
        pages[name] = page

        local button = Instance.new('TextButton')
        button.Name = name .. 'Tab'
        button.Position = UDim2.new((index - 1) / #entries, 0, 0, 0)
        button.Size = UDim2.new(1 / #entries, -1, 0, 48)
        button.BackgroundColor3 = colors.navigation
        button.BorderSizePixel = 0
        button.Text = icon .. ' ' .. name
        button.TextColor3 = colors.text
        button.TextSize = 15
        button.TextWrapped = true
        button.Font = Enum.Font.SourceSansSemibold
        button.Selectable = true
        button.AutoButtonColor = true
        button.Parent = nav
        buttons[name] = button
        local indicator = Instance.new('Frame')
        indicator.Name = 'SelectedIndicator'
        indicator.AnchorPoint = Vector2.new(0, 1)
        indicator.Position = UDim2.fromScale(0, 1)
        indicator.Size = UDim2.new(1, 0, 0, 3)
        indicator.BackgroundColor3 = colors.accent
        indicator.BorderSizePixel = 0
        indicator.Visible = false
        indicator.Parent = button
        indicators[name] = indicator
    end

    local statusArea = Instance.new('ScrollingFrame')
    statusArea.Name = 'StatusArea'
    statusArea.Position = UDim2.new(0, 0, 1, -100)
    statusArea.Size = UDim2.new(1, 0, 0, 50)
    statusArea.BackgroundColor3 = colors.background
    statusArea.BackgroundTransparency = 0
    statusArea.ZIndex = 2
    statusArea.BorderSizePixel = 0
    statusArea.ScrollBarThickness = 4
    statusArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    statusArea.CanvasSize = UDim2.new()
    statusArea.Parent = shell
    local status = textLabel('Status', 'Ready.', 50)
    status.Position = UDim2.fromOffset(10, 0)
    status.Size = UDim2.new(1, -26, 0, 50)
    status.ZIndex = 3
    status.TextColor3 = colors.muted
    status.Parent = statusArea

    local actions = Instance.new('Frame')
    actions.Name = 'Actions'
    actions.Position = UDim2.new(0, 10, 1, -46)
    actions.Size = UDim2.new(1, -20, 0, 38)
    actions.BackgroundTransparency = 1
    actions.Parent = shell

    -- At dock widths below 360 px, use two rows to keep full text labels legible.
    local function layoutNavigation()
        local narrow = shell.AbsoluteSize.X < 360
        local columns = if narrow then 2 else 4
        local height = if narrow then 96 else 48
        nav.Size = UDim2.new(1, 0, 0, height)
        for index, entry in ipairs(entries) do
            local button = buttons[entry[1]]
            local column = (index - 1) % columns
            local row = math.floor((index - 1) / columns)
            button.Position = UDim2.new(column / columns, 0, 0, row * 48)
            button.Size = UDim2.new(1 / columns, -1, 0, 48)
        end
        for _, page in pairs(pages) do
            page.Position = UDim2.fromOffset(0, height)
            page.Size = UDim2.new(1, 0, 1, -(height + 102))
        end
    end
    shell:GetPropertyChangedSignal('AbsoluteSize'):Connect(layoutNavigation)
    layoutNavigation()

    local api = { root = shell, pages = pages, buttons = buttons, status = status, actions = actions }
    function api:select(name: string): boolean
        if not pages[name] then return false end
        for key, page in pairs(pages) do
            local selected = key == name
            page.Visible = selected
            buttons[key].BackgroundColor3 = if selected then colors.selected else colors.navigation
            indicators[key].Visible = selected
        end
        return true
    end
    function api:setStatus(message: string, severity: string?)
        status.Text = message
        statusArea.CanvasPosition = Vector2.new(0, 0)
        status.TextColor3 = if severity == 'error' then colors.error elseif severity == 'warning' then colors.warning else colors.muted
    end
    function api:section(pageName: string, title: string, description: string?): Frame
        local page = pages[pageName]
        assert(page, 'Unknown panel page: ' .. tostring(pageName))
        local card = Instance.new('Frame')
        card.Name = title .. 'Section'
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = colors.card
        card.BorderSizePixel = 0
        local corner = Instance.new('UICorner'); corner.CornerRadius = UDim.new(0, 5); corner.Parent = card
        padding(card, 10)
        list(card, 5)
        local heading = textLabel('Title', title, 20)
        heading.Font = Enum.Font.SourceSansBold
        heading.TextSize = 18
        heading.LayoutOrder = 1
        heading.Parent = card
        if description and description ~= '' then
            local detail = textLabel('Description', description, 18)
            detail.TextColor3 = colors.muted
            detail.LayoutOrder = 2
            detail.Parent = card
        end
        card.Parent = page
        return card
    end
    -- A one-shot scene query, not an authored foot-alignment setting. The
    -- caller supplies the selected chain and performs the actual raycast.
    function api:contactProbe(onRequest)
        assert(type(onRequest) == 'function', 'contact diagnostic requires a request callback')
        local card = self:section('Alignment', 'Scene contact check',
            'Unsaved snapshot; check again after the scene changes. Requires a running viewport simulation. Probes straight down in world space from the ghost chain’s starting endpoint, not the draggable target. A hit does not establish foot support or move the ghost.')
        local context = textLabel('ChainContext', 'Start a viewport simulation for a saved chain.', 20)
        context.LayoutOrder = 3
        context.TextColor3 = colors.muted
        context.Parent = card

        local function numericField(name: string, caption: string, initial: string, position: number): TextBox
            local title = textLabel(name .. 'Label', caption, 20)
            title.LayoutOrder = position
            title.Parent = card
            local box = Instance.new('TextBox')
            box.Name = name
            box.LayoutOrder = position + 1
            box.Size = UDim2.new(1, 0, 0, 30)
            box.BackgroundColor3 = Color3.fromRGB(55, 61, 72)
            box.BorderSizePixel = 0
            box.TextColor3 = colors.text
            box.TextSize = 16
            box.Font = Enum.Font.SourceSans
            box.Text = initial
            box.ClearTextOnFocus = false
            box.Parent = card
            return box
        end
        local distance = numericField('ProbeDistance', 'Probe distance (studs)', '4', 4)
        local slope = numericField('MaximumSlope', 'Maximum slope (degrees)', '45', 6)
        local soleOffset = numericField('SoleOffset', 'Candidate offset along surface normal (studs)', '0', 8)
        local button = Instance.new('TextButton')
        button.Name = 'CheckSceneSurface'
        button.Text = 'Check scene surface'
        button.Size = UDim2.new(1, 0, 0, 36)
        button.LayoutOrder = 10
        button.BackgroundColor3 = Color3.fromRGB(42, 115, 151)
        button.BorderSizePixel = 0
        button.TextColor3 = colors.text
        button.Font = Enum.Font.SourceSansBold
        button.TextSize = 16
        button.Parent = card
        local result = textLabel('ContactResult', 'Contact: not evaluated.', 20)
        result.LayoutOrder = 11
        result.TextColor3 = colors.muted
        result.Parent = card
        for _, field in ipairs({distance, slope, soleOffset}) do
            field:GetPropertyChangedSignal('Text'):Connect(function()
                result.Text = 'Settings changed. Contact not evaluated.'
            end)
        end

        local ready = false
        local probe = {root = card, context = context, distance = distance, slope = slope, soleOffset = soleOffset, result = result, button = button}
        function probe:setContext(description: string, available: boolean)
            context.Text = description
            ready = available
            result.Text = 'Contact: not evaluated.'
        end
        function probe:setResult(message: string)
            result.Text = message
        end
        function probe:request(): boolean
            if not ready then
                result.Text = 'Start a viewport simulation for a saved chain before checking contact.'
                return false
            end
            local distanceValue, slopeValue, offsetValue = tonumber(distance.Text), tonumber(slope.Text), tonumber(soleOffset.Text)
            if not distanceValue or distanceValue ~= distanceValue or distanceValue <= 0 or distanceValue > 15000 then
                result.Text = 'Probe distance must be greater than zero and at most 15000 studs.'
                return false
            end
            if not slopeValue or slopeValue ~= slopeValue or slopeValue < 0 or slopeValue > 90 then
                result.Text = 'Maximum slope must be a number from 0 to 90 degrees.'
                return false
            end
            if not offsetValue or offsetValue ~= offsetValue or math.abs(offsetValue) == math.huge then
                result.Text = 'Candidate offset must be a finite number.'
                return false
            end
            result.Text = 'Checking scene surface…'
            local ok, err = pcall(onRequest, {distance = distanceValue, maxSlopeDegrees = slopeValue, soleOffset = offsetValue})
            if not ok then
                result.Text = 'Contact check failed: ' .. tostring(err)
                return false
            end
            return true
        end
        button.Activated:Connect(function() probe:request() end)
        return probe
    end
    function api:destroy()
        shell:Destroy()
    end
    for name, button in pairs(buttons) do
        button.Activated:Connect(function() api:select(name) end)
    end
    api:select('Rig')
    return api
end

return PanelComponents
