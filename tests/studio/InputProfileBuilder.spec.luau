local model=Instance.new('Model')
local a=Instance.new('Motor6D'); a.Name='A'; a.Parent=model
local part=Instance.new('Part'); part.Parent=model
local b=Instance.new('Bone'); b.Name='B'; b.Parent=part
a:SetAttribute('EditRigIK_HoldKey','E'); a:SetAttribute('EditRigIK_ImpulseKey','Q')
b:SetAttribute('EditRigIK_HoldKey','F')
local definition=Instance.new('Folder'); definition.Name='EditRigIKActor'; definition:SetAttribute('EditRigIK_ActorSchemaVersion',1); definition.Parent=model
local function ref(name,joint)
 local r=Instance.new('ObjectValue'); r.Name=name; r.Value=joint; r:SetAttribute('Control','Bite'); r:SetAttribute('Impulse','Snap'); r.Parent=definition
end
ref('A',a); ref('B',b)
local context=InputProfileBuilder.create(definition)
assert(context.Parent==nil and context:IsA('InputContext') and not context.Enabled,'template must be detached and disabled')
local actions=context:GetChildren(); assert(#actions==2,'shared route should group keys')
local hold,impulse
for _,action in ipairs(actions) do if action:GetAttribute('Route')=='Hold' then hold=action else impulse=action end end
assert(hold:GetAttribute('Control')=='Bite' and #hold:GetChildren()==2,'hold action must capture both keys')
assert(impulse:GetAttribute('Control')=='Snap' and #impulse:GetChildren()==1,'impulse action must capture key')
b:SetAttribute('EditRigIK_HoldKey','Q')
assert(not pcall(function() InputProfileBuilder.create(definition) end),'conflicting key routes must be rejected')
b:SetAttribute('EditRigIK_HoldKey','')
definition.B:SetAttribute('Kind','Ball'); definition.B:SetAttribute('Axis','X'); definition.B:SetAttribute('Impulse','Push'); b:SetAttribute('EditRigIK_ImpulseKey','F')
local withBall=InputProfileBuilder.create(definition)
local ballAction=nil
for _,action in ipairs(withBall:GetChildren()) do if action:GetAttribute('Control')=='Push' then ballAction=action end end
assert(ballAction and ballAction:GetAttribute('Value')==Vector3.xAxis,'ball input should use its configured axis vector')
withBall:Destroy()
definition.B:SetAttribute('Control','Aim'); b:SetAttribute('EditRigIK_HoldKey','F'); b:SetAttribute('EditRigIK_ImpulseKey','')
local other=Instance.new('Bone'); other.Name='C'; other.Parent=part; other:SetAttribute('EditRigIK_HoldKey','G')
ref('C',other); definition.C:SetAttribute('Kind','Ball'); definition.C:SetAttribute('Axis','Y'); definition.C:SetAttribute('Control','Aim')
assert(not pcall(function() InputProfileBuilder.create(definition) end),'shared vector controls with different axes must be rejected')
definition.C:Destroy(); other:Destroy(); b:SetAttribute('EditRigIK_HoldKey','')
b:SetAttribute('EditRigIK_ImpulseKey','')
local hingeOnly=InputProfileBuilder.create(definition)
assert(#hingeOnly:GetChildren()==2,'unmapped ball joints should not block hinge bindings')
hingeOnly:Destroy()
context:Destroy(); model:Destroy()
return 'Input profile groups shared routes and rejects collisions'
