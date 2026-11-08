assert(ChainPathView,'ChainPathView module required')
local holder=Instance.new('Frame')
local first=Instance.new('Motor6D'); first.Name='Hip'
local middle=Instance.new('Motor6D'); middle.Name='Knee'
local last=Instance.new('Motor6D'); last.Name='Ankle'
local endpoint=Instance.new('Attachment'); endpoint.Name='ToeTip'
local chosen=nil
local view=ChainPathView.new(holder,function(joint) chosen=joint end)
view:set({ok=true,joints={first,middle,last},rootSource='inferred',endpointSource='inferred',endpoint=endpoint},middle)
assert(view.root.Parent==holder,'chain view belongs to the supplied panel')
assert(view.root:FindFirstChild('Joint1',true).Text:find('Hip'),'root is visible')
assert(view.root:FindFirstChild('Joint2',true).Text:find('Knee'),'middle joint is visible')
assert(view.root:FindFirstChild('Joint3',true).Text:find('Ankle'),'end is visible')
assert(view.root:FindFirstChild('Message',true).Text:find('ToeTip',1,true),'inferred endpoint name is visible')
assert(view.root:FindFirstChild('Joint2',true):GetAttribute('Selected')==true,'selected joint is identified')
assert(view:choose(1) and chosen==first,'choosing a row selects the same joint')
view:set({ok=true,joints={first},rootSource='explicit',endpointSource='explicit',endpoint=endpoint},first)
assert(view.root:FindFirstChild('Joint1',true).Text:find('Root / End',1,true),'single-joint chains identify both roles')
assert(view.root:FindFirstChild('Message',true).Text:find('explicit',1,true),'explicit selection is distinguished from inference')
local many={}; for i=1,20 do many[i]=first end
view:set({ok=true,joints=many,rootSource='inferred',endpointSource='inferred',endpoint=endpoint},first)
local list=view.root:FindFirstChild('JointList',true)
assert(list and list:IsA('ScrollingFrame') and list.Size.Y.Offset<=150,'long chains remain compact and scrollable')
view:set({ok=false,reason='ambiguous',message='Multiple branches.'},middle)
assert(not view.root:FindFirstChild('Joint1',true) and not view:choose(1),'ambiguous chains are not shown as guessed paths')
assert(view.root:FindFirstChild('Message',true).Text:find('Multiple branches',1,true),'ambiguous reason is visible')
view:set(nil,nil)
assert(not view:choose(1),'clearing selection removes stale chain actions')
view:destroy(); assert(#holder:GetChildren()==0,'view cleanup removes controls')
first:Destroy(); middle:Destroy(); last:Destroy(); endpoint:Destroy(); holder:Destroy()
return 'Chain path view selection, ambiguity and cleanup passed'
