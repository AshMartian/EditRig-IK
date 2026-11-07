local model=Instance.new('Model')
local root=Instance.new('Part'); root.Parent=model
local folder=Instance.new('Folder'); folder.Parent=model; folder:SetAttribute('EditRigIK_ActorSchemaVersion',1)
for _,entry in ipairs({{'Jaw','Bite','Snap'},{'Tail','Bite','Snap'},{'Leg','Step','Kick'}}) do
 local joint=Instance.new('Motor6D'); joint.Parent=root
 local ref=Instance.new('ObjectValue'); ref.Name=entry[1]; ref.Value=joint; ref.Parent=folder
 ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('LowerDegrees',-45); ref:SetAttribute('UpperDegrees',90)
 ref:SetAttribute('Control',entry[2]); ref:SetAttribute('Impulse',entry[3]); ref:SetAttribute('Frequency',4)
end
local actor=ActorRig.new(folder,{Actor=Actor,JointDrive=JointDrive,JointAdapter=JointAdapter})
local controls=actor:listControls(); local impulses=actor:listImpulses()
assert(#controls==2 and controls[1]=='Bite' and controls[2]=='Step','controls should be unique and sorted')
assert(#impulses==2 and impulses[1]=='Kick' and impulses[2]=='Snap','impulses should be unique and sorted')
controls[1]='changed'; assert(actor:listControls()[1]=='Bite','lists must not expose internal state')
assert(not pcall(function() actor:setControl('Typo',1) end),'unknown control must fail immediately')
assert(not pcall(function() actor:clearControl('Typo') end),'unknown cleared control must fail')
assert(not pcall(function() actor:impulse('Typo',1) end),'unknown impulse must fail immediately')
assert(not pcall(function() actor:setControl('Bite',true) end),'non-scalar controls must fail immediately')
assert(not pcall(function() actor:impulse('Snap',{1,2,3}) end),'non-scalar impulse must fail before queueing')
assert(not pcall(function() actor:impulse('Snap',0/0) end),'non-finite impulse must fail')
actor:setControl('Bite',.5); actor:impulse('Snap',1)
local result=actor:step(.1)
assert(result.Jaw>math.pi/4 and result.Tail>math.pi/4,'valid shared routes should still drive both joints')
actor:destroy(); assert(not pcall(function() actor:listControls() end),'destroyed actor must reject access')
model:Destroy()
return 'Actor exposes and validates named control and impulse routes'
