assert(PanelComponents, 'panel components required')
-- A viewport handle can select the same field without taking keyboard focus;
-- typed input and the handle both edit the same draft, never save implicitly.
local fields = {}
for _, key in ipairs({'lower', 'upper', 'swing'}) do
    fields[key] = Instance.new('TextBox')
    fields[key].Text = '0'
end
local focusEvents = {}
local binding = PanelComponents.bindLimitInputs(fields, function(key)
    table.insert(focusEvents, key)
end)
assert(binding:select('lower') and binding.active == 'lower', 'handle selection identifies the matching field')
assert(fields.lower:FindFirstChild('LimitSelection').Enabled and not fields.upper:FindFirstChild('LimitSelection').Enabled, 'only the matching field is highlighted')
assert(binding:setValue('lower', -45.25) and fields.lower.Text == '-45.25', 'viewport edits update the linked numeric draft')
assert(not binding:setValue('lower', math.huge) and fields.lower.Text == '-45.25', 'nonfinite handle values do not enter the draft')
assert(not binding:select('missing') and binding.active == 'lower', 'unknown handle leaves selection unchanged')
binding:begin('lower')
fields.lower.Text = '-3'
assert(binding:cancel() and fields.lower.Text == '-45.25', 'Escape restores the field value from the start of editing')
assert(not binding:cancel(), 'cancel cannot repeatedly restore an old snapshot')
binding:begin('upper'); fields.upper.Text = '10'
binding:finish('upper')
assert(not binding:cancel() and fields.upper.Text == '10', 'finished edits are not undone by later Escape')
binding:begin('lower'); binding:abandon(); fields.lower.Text = '42'
assert(not binding:cancel() and fields.lower.Text == '42', 'changing joint discards the previous edit snapshot')
binding:select(nil)
assert(not fields.lower:FindFirstChild('LimitSelection').Enabled and not fields.upper:FindFirstChild('LimitSelection').Enabled, 'selection can be cleared')
assert(#focusEvents > 0 and focusEvents[1] == 'lower', 'selection notifies the linked viewport')
binding:destroy(); binding:destroy()
for _, box in pairs(fields) do assert(not box:FindFirstChild('LimitSelection'), 'destroy removes owned highlights'); box:Destroy() end
local host = Instance.new('Frame')
host.Size = UDim2.fromOffset(320, 420)
local panel = PanelComponents.new(host)
assert(panel.buttons.Rig.Size.X.Scale == 0.5, 'narrow navigation uses two readable columns')
assert(panel.buttons.Alignment.Position.Y.Offset == 48, 'narrow navigation wraps tabs to a second row')
assert(panel.status.Parent:IsA('ScrollingFrame'), 'long status can scroll instead of being clipped')
assert(panel.status.Parent.BackgroundTransparency == 0, 'status has an opaque surface')
assert(panel.status.Parent.Size.X.Scale == 1 and panel.status.Parent.Size.X.Offset == 0, 'status surface spans the panel width')
for _, page in pairs(panel.pages) do
    assert(page.ClipsDescendants, 'page content is clipped to its scroll viewport')
    assert(page.Position.Y.Offset + page.Size.Y.Offset <= panel.status.Parent.Position.Y.Offset, 'page ends above the status area')
end
assert(panel.status.AutomaticSize == Enum.AutomaticSize.Y, 'status expands to fit wrapped text')
assert(panel.pages.Rig.Visible and not panel.pages.Alignment.Visible, 'Rig is the initial page')
assert(panel:select('Alignment'), 'known page can be selected')
assert(panel.pages.Alignment.Visible and not panel.pages.Rig.Visible, 'only the selected page is visible')
assert(not panel:select('unknown') and panel.pages.Alignment.Visible, 'unknown page leaves selection unchanged')
assert(panel.buttons.Alignment.Text:find('Alignment', 1, true), 'navigation retains text labels')
assert(panel.buttons.Alignment.Selectable, 'navigation is keyboard selectable')
panel:setStatus('Select a supported chain.', 'warning')
assert(panel.status.Text == 'Select a supported chain.', 'status is persistent and readable')
local card = panel:section('Alignment', 'Feet', 'Settings are unavailable.')
assert(card.Parent == panel.pages.Alignment and card:FindFirstChild('Title').Text == 'Feet', 'sections have explicit headings')
local action = Instance.new('TextButton'); action.Text = 'Example action'; action.Parent = panel.actions
panel:select('Rig')
assert(panel.status.Text == 'Select a supported chain.' and action.Parent == panel.actions, 'page changes preserve status and action area')
panel:destroy(); panel:destroy()
assert(#host:GetChildren() == 0, 'destroy removes the panel and is idempotent')
host:Destroy()
-- Contact probe is a session-only scene diagnostic; a ray hit is not a planted foot.
local probeHost = Instance.new('Frame')
local diagnosticPanel = PanelComponents.new(probeHost)
local requests = {}
local probe = diagnosticPanel:contactProbe(function(options)
    table.insert(requests, options)
end)
assert(probe.root.Parent == diagnosticPanel.pages.Alignment, 'contact diagnostic belongs to Alignment')
assert(probe.context.Text:find('simulation', 1, true), 'missing simulation prerequisite is visible')
assert(not probe:request() and #requests == 0, 'missing chain prevents a probe')
probe:setContext('Left foot chain — Endpoint', true)
probe.distance.Text = '4'; probe.slope.Text = '45'; probe.soleOffset.Text = '-0.1'
assert(probe:request() and #requests == 1, 'valid inputs submit one request')
assert(requests[1].distance == 4 and requests[1].maxSlopeDegrees == 45 and requests[1].soleOffset == -0.1, 'settings preserve numeric values')
probe.distance.Text = '0'
assert(not probe:request() and #requests == 1 and probe.result.Text:find('distance', 1, true), 'invalid distance is explained and never submitted')
probe.distance.Text = '4'; probe.slope.Text = '91'
assert(not probe:request() and #requests == 1 and probe.result.Text:find('slope', 1, true), 'invalid slope is explained and never submitted')
probe.slope.Text = 'nan'
assert(not probe:request() and #requests == 1, 'nonfinite or nonnumeric values are rejected')
probe.slope.Text = '45'; probe.distance.Text = '15001'
assert(not probe:request() and #requests == 1, 'distances beyond the Studio raycast maximum are rejected')
probe.distance.Text = '4'; probe.soleOffset.Text = 'nan'
assert(not probe:request() and #requests == 1 and probe.result.Text:find('offset', 1, true), 'invalid offset is explained')
probe:setResult('No contact')
assert(probe.result.Text == 'No contact', 'scene result is visible')
probe.slope.Text = '35'
task.wait()
assert(probe.result.Text:find('not evaluated', 1, true), 'editing probe inputs clears a stale scene result')
probe:setContext('Select a saved chain.', false)
assert(probe.result.Text:find('not evaluated', 1, true), 'changing selection clears stale contact results')
local alignments = {}
local visual = diagnosticPanel:contactProbe(function() end, function(settings) table.insert(alignments, settings) end)
assert(visual.soleUp and visual.soleForward and visual.strength and visual.previewButton, 'alignment preview exposes explicit local frame and strength fields')
assert(not visual:preview() and #alignments == 0, 'preview requires an active simulation')
visual:setContext('Foot', true)
assert(visual:preview() and #alignments == 1, 'configured preview sends a request')
assert(alignments[1].soleUp[2] == 1 and alignments[1].soleForward[3] == -1 and alignments[1].strength == 1, 'defaults use explicit local axes and full strength')
visual.soleUp.Text = '1, 0, 0'; visual.soleForward.Text = '0, 1, 0'; visual.strength.Text = '0.5'
assert(visual:preview() and #alignments == 2, 'configured axes and strength are accepted')
assert(alignments[2].soleUp[1] == 1 and alignments[2].soleForward[2] == 1 and alignments[2].strength == .5, 'preview preserves configured values')
for _,change in ipairs({
 function() visual.soleUp.Text = '0,0,0' end,
 function() visual.soleUp.Text = 'inf,0,0' end,
 function() visual.soleUp.Text = '1,2,3,4' end,
 function() visual.soleUp.Text = '0,1,0'; visual.soleForward.Text = '0,-2,0' end,
 function() visual.soleForward.Text = '0,0,-1'; visual.strength.Text = '-.1' end,
 function() visual.strength.Text = '1.1' end,
}) do change(); assert(not visual:preview() and #alignments == 2, 'invalid preview options must not be sent') end
visual:setResult('Previously evaluated'); visual.soleForward.Text = '1,0,0'; task.wait()
assert(visual.result.Text:find('not evaluated', 1, true), 'editing alignment axes invalidates stale result')
diagnosticPanel:destroy(); probeHost:Destroy()

return 'Panel page navigation, contact diagnostic, status, sections, and cleanup passed'
