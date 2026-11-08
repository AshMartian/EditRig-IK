local api=LimitDraft.new(Config)
local joint=Instance.new('Bone')
local input={kind='Hinge',axis='X',lower=-90,upper=90,swing=90,weight=1}
assert(api.classify(nil,input)=='none')
assert(api.classify(joint,input)=='unconfigured','default fields are not saved limits')
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
joint:Destroy()
return 'Limit draft states and metadata validation passed'
