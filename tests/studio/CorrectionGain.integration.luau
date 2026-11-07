local model=Instance.new('Model')
local part=Instance.new('Part'); part.Parent=model
local endPart=Instance.new('Part'); endPart.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=part; motor.Part1=endPart; motor.Parent=part
local bone=Instance.new('Bone'); bone.Parent=part
local container=Instance.new('Folder'); container.Name='EditRigIKChains'; container.Parent=model
local builder=ChainBuilder.new(Config)
for _,joint in ipairs({motor,bone}) do
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',90)
 local tip=Instance.new('Attachment'); tip.Position=Vector3.xAxis; tip.Parent=if joint:IsA('Motor6D') then endPart else bone
 local definition=builder.create(model,joint,joint,tip,joint.ClassName,{iterations=1,tolerance=0,gain=.5}); definition.Parent=container
 assert(builder.readSettings(definition).gain==.5,'authored gain must persist')
 local function open()
  return ChainDefinition.new(definition,{exclusive=true},function(joints,point,options) return ChainAdapter.new(joints,point,options,Solver.new(Limits)) end)
 end
 local chain=open(); chain:solve(Vector3.yAxis)
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/4),1e-5),'authored gain must scale actual joint correction')
 chain:destroy()
 builder.writeSettings(definition,{iterations=1,tolerance=0,gain=.25})
 chain=open(); chain:solve(Vector3.yAxis,{gain=1})
 assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/2),1e-5),'gain override must reach solver')
 chain:destroy()
 definition:SetAttribute('CorrectionGain',nil)
 assert(builder.readSettings(definition).gain==1,'old definitions default to full gain')
 definition:SetAttribute('CorrectionGain',0)
 assert(not pcall(open),'invalid saved gain must be rejected')
 tip:Destroy(); definition:Destroy()
end
model:Destroy()
return 'Authored gain controls Motor6D and Bone corrections and legacy defaults'
