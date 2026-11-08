local api=LimitDraft.new(Config)
local joint=Instance.new('Bone')
local input={kind='Hinge',axis='X',lower=-90,upper=90,swing=90,weight=1}
assert(api.classify(nil,input)=='none')
assert(api.classify(joint,input)=='unconfigured','default fields are not saved limits')
assert(api.classify(joint,input,true)=='draft','explicit or edited unsaved defaults are a visible draft')
assert(joint:GetAttribute('EditRigIK_SchemaVersion')==nil,'starting a draft does not write metadata')
local invalidDraft=table.clone(input); invalidDraft.lower=100
assert(api.classify(joint,invalidDraft,true)=='invalid','invalid unsaved drafts cannot be shown as valid')
local attrs={kind='EditRigIK_Kind',axis='EditRigIK_Axis',lower='EditRigIK_LowerDegrees',upper='EditRigIK_UpperDegrees',swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
for key,name in pairs(attrs) do joint:SetAttribute(name,input[key]) end
assert(api.classify(joint,input)=='invalidSaved','partial metadata must not appear saved')
joint:SetAttribute('EditRigIK_SchemaVersion',1)
assert(api.classify(joint,input)=='saved')
local changed=table.clone(input); changed.lower=-30
assert(api.classify(joint,changed)=='draft')
changed.lower=100
assert(api.classify(joint,changed)=='invalid')
joint:SetAttribute('EditRigIK_Kind','Bad')
assert(api.classify(joint,input)=='invalidSaved')
joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Weight',nil)
assert(api.classify(joint,input)=='saved','legacy missing weight defaults to one')
local circular=table.clone(input); circular.lower=170; circular.upper=-150; circular.circular={start=170,width=40}
joint:SetAttribute('EditRigIK_LowerDegrees',170); joint:SetAttribute('EditRigIK_UpperDegrees',-150)
joint:SetAttribute('EditRigIK_SchemaVersion',2)
joint:SetAttribute('EditRigIK_CircularStartDegrees',170)
joint:SetAttribute('EditRigIK_CircularWidthDegrees',40)
assert(api.classify(joint,circular)=='saved', 'circular draft matches persisted interval')
local changedCircular=table.clone(circular); changedCircular.circular={start=170,width=41}; changedCircular.upper=-149
assert(api.classify(joint,changedCircular)=='draft', 'circular interval changes are unsaved')
assert(api.classify(joint,input)=='draft', 'dropping circular data is a changed draft')
joint:SetAttribute('EditRigIK_CircularWidthDegrees',nil)
assert(api.classify(joint,circular)=='invalidSaved', 'incomplete circular metadata cannot appear saved')
joint:Destroy()
return 'Limit draft states and metadata validation passed'
