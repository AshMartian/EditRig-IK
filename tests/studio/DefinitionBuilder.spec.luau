local model=Instance.new('Model')
local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Jaw'; motor.Parent=part
local bone=Instance.new('Bone'); bone.Name='Tail'; bone.Parent=part
local function set(joint,kind,axis)
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind',kind)
 joint:SetAttribute('EditRigIK_Axis',axis); joint:SetAttribute('EditRigIK_LowerDegrees',-45)
 joint:SetAttribute('EditRigIK_UpperDegrees',90); joint:SetAttribute('EditRigIK_SwingDegrees',45)
end
set(motor,'Hinge','Y'); set(bone,'Hinge','Z')
local builder=DefinitionBuilder.new(Config)
local definition=builder.create(model)
assert(definition.Parent==nil and #definition:GetChildren()==2)
assert(definition.Jaw.Value==motor and definition.Jaw:GetAttribute('Control')=='Jaw')
assert(definition.Tail.Value==bone and definition.Tail:GetAttribute('UpperDegrees')==90)
set(bone,'Ball','Z')
assert(not pcall(function() builder.create(model) end),'unsupported ball limits must not silently degrade')
definition:Destroy(); model:Destroy()
return 'Definition builder validated Motor6D and Bone configuration'
