local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local endpointPart=Instance.new('Part'); endpointPart.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Knee'; motor.Part0=part; motor.Part1=endpointPart; motor.Parent=part
local bone=Instance.new('Bone'); bone.Name='TailRoot'; bone.Parent=part
local container=Instance.new('Folder'); container.Name='EditRigIKChains'; container.Parent=model
for _,joint in ipairs({motor,bone}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',0); joint:SetAttribute('EditRigIK_UpperDegrees',45); joint:SetAttribute('EditRigIK_SwingDegrees',90)
 local tip=Instance.new('Attachment'); tip.Position=Vector3.xAxis; tip.Parent=if joint:IsA('Motor6D') then endpointPart else bone
 local def=ChainBuilder.new(Config).create(model,joint,joint,tip,joint.Name,{iterations=4,tolerance=.001}); def.Parent=container
 local chain=ChainDefinition.new(def,{exclusive=true},function(joints,point,options) return ChainAdapter.new(joints,point,options,Solver.new(Limits)) end)
 local result=chain:solve(Vector3.yAxis)
 assert(result.limitedJoints[1]==1 and result.limitedJointNames[1]==joint.Name,'named diagnostics must correspond to the clamped chain joint')
 chain:destroy(); tip:Destroy(); def:Destroy()
end
model:Destroy()
return 'Configured Motor6D and Bone chains report limited joint names'
