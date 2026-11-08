local function fixture()
 local model=Instance.new('Model'); local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
 local definition=Instance.new('Folder'); definition.Name='Leg'; definition.Parent=folder
 local part=Instance.new('Part'); part.Parent=model
 local motor=Instance.new('Motor6D'); motor.Parent=part
 local selected=definition; local edit=true
 local selectedEvent=Instance.new('BindableEvent'); local stateEvent=Instance.new('BindableEvent')
 local selection={SelectionChanged=selectedEvent.Event,Get=function() return if selected then {selected} else {} end}
 local run={IsEdit=function() return edit end,GetPropertyChangedSignal=function(_,name) assert(name=='RunState'); return stateEvent.Event end}
 return model,definition,part,motor,selection,run,selectedEvent,stateEvent,function(value) selected=value end,function(value) edit=value end
end
assert(PreviewGuard,'preview lifecycle guard required')
local model,definition,part,motor,selection,run,selectEvent,stateEvent,setSelected,setEdit=fixture()
local reasons={}
local function start() return PreviewGuard.new(model,definition,selection,run,function(reason) table.insert(reasons,reason) end) end
local guard=start(); motor.C0=CFrame.new(1,0,0); task.wait()
assert(#reasons==1 and reasons[1]=='source changed','joint edits must invalidate the preview')
part.Name='AfterInvalidation'; task.wait(); assert(#reasons==1,'invalidated guard must disconnect')
guard:destroy(); guard:destroy()
guard=start(); definition:SetAttribute('Iterations',4); task.wait(); assert(reasons[#reasons]=='source changed','chain settings invalidate preview')
guard=start(); local item=Instance.new('Folder'); item.Parent=model; task.wait(); assert(reasons[#reasons]=='source changed','hierarchy additions invalidate preview')
guard=start(); setSelected(part); selectEvent:Fire(); task.wait(); assert(reasons[#reasons]=='selection changed','selection change invalidates preview')
setSelected(definition); guard=start(); setEdit(false); stateEvent:Fire(); task.wait(); assert(reasons[#reasons]=='left Edit mode','Play or Pause invalidates preview')
setEdit(true); guard=start(); setSelected(part); assert(not guard:check() and reasons[#reasons]=='selection changed','synchronous check must reject changed selection before deferred events')
setSelected(definition); guard=start(); setEdit(false); assert(not guard:check() and reasons[#reasons]=='left Edit mode','synchronous check must reject non-edit state')
setEdit(true); guard=start(); guard:destroy(); local count=#reasons; part.Name='Closed'; task.wait(); assert(#reasons==count,'closed guard must not fire callbacks')
selectEvent:Destroy(); stateEvent:Destroy(); model:Destroy()
return 'Preview lifecycle invalidation and cleanup passed'
