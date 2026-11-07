local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local first=Instance.new('Motor6D'); first.Name='Jaw'; first.Parent=part
local function configure(joint)
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-45); joint:SetAttribute('EditRigIK_UpperDegrees',90); joint:SetAttribute('EditRigIK_SwingDegrees',90)
end
configure(first)
local builder=DefinitionBuilder.new(Config); local definition=builder.create(model); definition.Parent=model
local existing=definition.Jaw; existing:SetAttribute('Control','HandEdited')
local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=part; configure(bone)
local pending=builder.prepareAdd(definition)
assert(#pending==1 and #definition:GetChildren()==1,'prepare should find the new bone without changing the actor')
assert(builder.addNew(definition)==1 and definition.Tail.Value==bone,'new bone should be added')
assert(definition.Jaw==existing and existing:GetAttribute('Control')=='HandEdited','existing binding and edits must remain')
assert(builder.addNew(definition)==0,'adding again must not duplicate existing references')
local collision=Instance.new('Motor6D'); collision.Name='Jaw'; collision.Parent=part; configure(collision)
local other=Instance.new('Motor6D'); other.Name='Leg'; other.Parent=part; configure(other)
assert(not pcall(function() builder.addNew(definition) end),'duplicate name must reject all additions')
assert(not definition:FindFirstChild('Leg') and #definition:GetChildren()==2,'failed validation must not add earlier joints')
collision:Destroy(); assert(builder.addNew(definition)==1 and definition.Leg.Value==other,'valid Motor6D should be added after collision resolved')
model:Destroy()
return 'Actor adds configured Motor6D and Bone joints without replacing existing bindings'
