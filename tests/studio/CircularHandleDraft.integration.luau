-- Source-level integration of the editor's draft callback protocol. Detached
-- instances deliberately avoid changing the open place or the source joint.
local parent=Instance.new('Part'); parent.CFrame=CFrame.new(3,5,7)*CFrame.Angles(.2,.4,.1)
local joint=Instance.new('Motor6D'); joint.Part0=parent; joint.C0=CFrame.Angles(.1,-.2,.3)
joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_LowerDegrees',-90); joint:SetAttribute('EditRigIK_UpperDegrees',170)
local originalC0=joint.C0
local gui=Instance.new('Folder')
local mouseMove=Instance.new('BindableEvent'); local mouseUp=Instance.new('BindableEvent')
local mouse={Move=mouseMove.Event,Button1Up=mouseUp.Event,UnitRay=Ray.new(Vector3.new(0,0,10),Vector3.new(0,0,-1))}
local fields={lower=Instance.new('TextBox'),upper=Instance.new('TextBox')}
fields.lower.Text='-90'; fields.upper.Text='170'
local draft=nil; local updating=false; local handles
local function setDraft(interval) draft=if interval then {start=interval.start,width=interval.width} else nil end
local function input() return {kind='Hinge',axis='Z',lower=tonumber(fields.lower.Text),upper=tonumber(fields.upper.Text),swing=45,weight=1,circular=draft} end
local binding=PanelComponents.bindLimitInputs(fields,nil,nil,function()
 return {circular=if draft then {start=draft.start,width=draft.width} else nil,lower=fields.lower.Text,upper=fields.upper.Text}
end,function(_,snapshot)
 updating=true; setDraft(snapshot.circular); fields.lower.Text=snapshot.lower; fields.upper.Text=snapshot.upper; updating=false
 handles:sync(joint,input())
end)
for _,key in ipairs({'lower','upper'}) do
 fields[key]:GetPropertyChangedSignal('Text'):Connect(function()
  if updating then return end
  if draft then
   local ok,interval=pcall(CircularDraft.setBound,draft,key,tonumber(fields[key].Text))
   if ok then setDraft(interval) end
  end
  handles:sync(joint,input())
 end)
end
handles=HingeLimitHandles.new(gui,mouse,Config,HingeDragMath,AxisGizmo.restFrame,function(bound,value,interval,restore)
 if interval or restore then
  updating=true; setDraft(interval)
  if restore then fields.lower.Text=tostring(restore.lower); fields.upper.Text=tostring(restore.upper)
  else fields.lower.Text=tostring(interval.start); fields.upper.Text=tostring(CircularDraft.endpoint(interval)) end
  updating=false
 else binding:setValue(bound,value) end
end)
assert(handles:set(joint,input()))
local frame=parent.CFrame*joint.C0
local function rayAt(angle)
 local p=frame:PointToWorldSpace(Vector3.new(math.cos(math.rad(angle)),math.sin(math.rad(angle)),0))
 return Ray.new(p+frame.LookVector*10,-frame.LookVector)
end
local function near(a,b) return math.abs(a-b)<1e-4 end
assert(handles:begin('upper',rayAt(170)) and handles:move(rayAt(-170)))
assert(draft and near(draft.start,-90) and near(draft.width,280) and near(tonumber(fields.upper.Text),-170),'seam crossing promotes legacy interval')
assert(handles:sync(joint,input()) and handles:move(rayAt(-160)) and near(draft.width,290),'matching editor sync keeps the promoted drag active')
handles:cancel(true)
assert(not draft and tonumber(fields.lower.Text)==-90 and tonumber(fields.upper.Text)==170,'cancel demotes and restores the exact legacy interval')
assert(handles:sync(joint,input())); assert(handles:begin('upper',rayAt(170))); assert(handles:move(rayAt(-170))); handles:finish()
fields.upper.Text='-150'; task.wait()
assert(draft and near(draft.width,300) and Config.validate(input()).circular,'numeric edit updates the same circular interval')
assert(binding:begin('upper')); fields.upper.Text='-140'; task.wait(); assert(near(draft.width,310)); assert(binding:cancel())
assert(near(draft.width,300) and tonumber(fields.upper.Text)==-150,'numeric cancel restores full interval and field together')
assert(joint.C0==originalC0 and joint:GetAttribute('EditRigIK_SchemaVersion')==1 and joint:GetAttribute('EditRigIK_LowerDegrees')==-90 and joint:GetAttribute('EditRigIK_UpperDegrees')==170 and joint:GetAttribute('EditRigIK_CircularWidthDegrees')==nil,'draft interactions leave the source joint and metadata unchanged')
binding:destroy(); handles:destroy(); fields.lower:Destroy(); fields.upper:Destroy(); gui:Destroy(); mouseMove:Destroy(); mouseUp:Destroy(); joint:Destroy(); parent:Destroy()
return 'circular handle and numeric draft integration passed'
