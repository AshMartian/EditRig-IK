assert(PanelComponents, 'panel components required')
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
diagnosticPanel:destroy(); probeHost:Destroy()

return 'Panel page navigation, contact diagnostic, status, sections, and cleanup passed'
