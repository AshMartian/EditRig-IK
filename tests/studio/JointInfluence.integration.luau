local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local endPart=Instance.new('Part'); endPart.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.Part1=endPart; motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local container=Instance.new('Folder'); container.Name='EditRigIKChains'; container.Parent=model
local builder=ChainBuilder.new(Config)
for _,joint in ipairs({motor,bone}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',90); joint:SetAttribute('EditRigIK_Weight',.5)
 local tip=Instance.new('Attachment'); tip.Position=Vector3.xAxis; tip.Parent=if joint:IsA('Motor6D') then endPart else bone
 local def=builder.create(model,joint,joint,tip,joint.ClassName,{iterations=1,tolerance=0}); def.Parent=container
 assert(def.Joints.Joint001:GetAttribute('Weight')==.5,'influence must be saved')
 local function open() return ChainDefinition.new(def,{exclusive=true},function(joints,point,options) return ChainAdapter.new(joints,point,options,Solver.new(Limits)) end) end
 local chain=open(); chain:solve(Vector3.yAxis)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/4),1e-5),'influence must scale the actual joint correction')
 chain:destroy(); joint:SetAttribute('EditRigIK_Weight',0); builder.refreshLimits(def)
 chain=open(); chain:solve(Vector3.yAxis)
 assert(joint.Transform:FuzzyEq(CFrame.identity,1e-5),'zero influence must prevent correction')
 chain:destroy(); def.Joints.Joint001:SetAttribute('Weight',nil)
 chain=open(); chain:solve(Vector3.yAxis)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5),'older definitions default to full influence')
 chain:destroy(); def.Joints.Joint001:SetAttribute('Weight',-1)
 assert(not pcall(open),'invalid saved influence must be rejected')
 tip:Destroy(); def:Destroy()
end
model:Destroy()
return 'Authored joint influence controls Motor6D and Bone solver corrections'
