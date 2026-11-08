--!strict
-- A read-only representation of a validated inferred path. Selecting a row
-- delegates to Studio Selection; no chain or rig metadata is written here.
local ChainPathView={}
function ChainPathView.new(parent,onSelect)
 assert(typeof(parent)=='Instance' and type(onSelect)=='function','panel and selection callback required')
 local root=Instance.new('Frame'); root.Name='InferredChainPath'
 root.Size=UDim2.new(1,0,0,0); root.AutomaticSize=Enum.AutomaticSize.Y
 root.BackgroundColor3=Color3.fromRGB(30,34,42); root.BorderSizePixel=0; root.Parent=parent
 local corner=Instance.new('UICorner'); corner.CornerRadius=UDim.new(0,5); corner.Parent=root
 local padding=Instance.new('UIPadding'); padding.PaddingTop=UDim.new(0,8); padding.PaddingBottom=UDim.new(0,8); padding.PaddingLeft=UDim.new(0,8); padding.PaddingRight=UDim.new(0,8); padding.Parent=root
 local layout=Instance.new('UIListLayout'); layout.Padding=UDim.new(0,3); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=root
 local heading=Instance.new('TextLabel'); heading.Name='Heading'; heading.Size=UDim2.new(1,0,0,24)
 heading.BackgroundTransparency=1; heading.TextXAlignment=Enum.TextXAlignment.Left
 heading.Text='Connected chain'; heading.Font=Enum.Font.SourceSansBold; heading.TextSize=17; heading.TextColor3=Color3.fromRGB(235,240,245); heading.Parent=root
 local message=Instance.new('TextLabel'); message.Name='Message'; message.LayoutOrder=1; message.Size=UDim2.new(1,0,0,30); message.AutomaticSize=Enum.AutomaticSize.Y
 message.BackgroundTransparency=1; message.TextXAlignment=Enum.TextXAlignment.Left; message.TextYAlignment=Enum.TextYAlignment.Top; message.TextWrapped=true
 message.Font=Enum.Font.SourceSans; message.TextSize=15; message.TextColor3=Color3.fromRGB(175,187,201); message.Text='Select a joint to inspect its chain.'; message.Parent=root
 local jointList=Instance.new('ScrollingFrame'); jointList.Name='JointList'; jointList.LayoutOrder=2
 jointList.Size=UDim2.new(1,0,0,0); jointList.BackgroundTransparency=1; jointList.BorderSizePixel=0
 jointList.ScrollBarThickness=5; jointList.AutomaticCanvasSize=Enum.AutomaticSize.Y; jointList.CanvasSize=UDim2.new(); jointList.Visible=false; jointList.Parent=root
 local rowLayout=Instance.new('UIListLayout'); rowLayout.Padding=UDim.new(0,3); rowLayout.SortOrder=Enum.SortOrder.LayoutOrder; rowLayout.Parent=jointList
 local rows,connections={},{}
 local result,selected=nil,nil
 local dead=false
 local api={root=root}
 local function clear()
  for _,connection in ipairs(connections) do connection:Disconnect() end
  for _,row in ipairs(rows) do row:Destroy() end
  table.clear(connections); table.clear(rows)
  jointList.Visible=false; jointList.Size=UDim2.new(1,0,0,0)
 end
 function api:choose(index)
  if dead or not result or not result.ok or type(index)~='number' or not result.joints[index] then return false end
  onSelect(result.joints[index]); return true
 end
 function api:set(nextResult,nextSelected)
  if dead then return end
  if result==nextResult and selected==nextSelected then return end
  result=nextResult; selected=nextSelected; clear()
  if not result then message.Text='Select a joint to inspect its chain.'; return end
  if not result.ok then message.Text='No unique chain: '..tostring(result.message or result.reason or 'choose a root and endpoint.'); return end
  local rootSource=if result.rootSource=='explicit' then 'explicit' else 'inferred'
  local endpointSource=if result.endpointSource=='explicit' then 'explicit' else 'inferred'
  local endpointName=if result.endpoint and result.endpoint.Name then result.endpoint.Name else 'unknown'
  message.Text='Root: '..rootSource..' · Endpoint: '..endpointName..' ('..endpointSource..'). Review before saving.'
  jointList.Size=UDim2.new(1,0,0,math.clamp(#result.joints*29-3,0,142)); jointList.Visible=#result.joints>0
  for index,joint in ipairs(result.joints) do
   local row=Instance.new('TextButton'); row.Name='Joint'..index; row.LayoutOrder=index+1
   row.Size=UDim2.new(1,0,0,26); row.BorderSizePixel=0
   row.BackgroundColor3=if joint==selected then Color3.fromRGB(39,91,105) else Color3.fromRGB(42,48,58)
   row.TextColor3=Color3.fromRGB(235,240,245); row.TextXAlignment=Enum.TextXAlignment.Left
   row.Font=Enum.Font.SourceSans; row.TextSize=15; row.TextTruncate=Enum.TextTruncate.AtEnd
   local marker=if #result.joints==1 then 'Root / End' elseif index==1 then 'Root' elseif index==#result.joints then 'End' else tostring(index)
   row.Text='  '..marker..'  ·  '..joint.Name; row:SetAttribute('Selected',joint==selected); row.Parent=jointList
   table.insert(rows,row); table.insert(connections,row.Activated:Connect(function() api:choose(index) end))
  end
 end
 function api:destroy()
  if dead then return end
  dead=true; clear(); root:Destroy()
 end
 api:set(nil,nil)
 return api
end
return ChainPathView
