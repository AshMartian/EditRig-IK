local model=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model
local c=Instance.new('Part'); c.Parent=model
local j1=Instance.new('Motor6D'); j1.Name='Hip'; j1.Part0=a; j1.Part1=b; j1.Parent=a
local j2=Instance.new('Motor6D'); j2.Name='Knee'; j2.Part0=b; j2.Part1=c; j2.Parent=b
local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.new(0,-1,0); endpoint.Parent=c
local function settings(j,kind)
 j:SetAttribute('EditRigIK_SchemaVersion',1); j:SetAttribute('EditRigIK_Kind',kind)
 j:SetAttribute('EditRigIK_Axis','X'); j:SetAttribute('EditRigIK_LowerDegrees',-30)
 j:SetAttribute('EditRigIK_UpperDegrees',90); j:SetAttribute('EditRigIK_SwingDegrees',45)
end
settings(j1,'Ball'); settings(j2,'Hinge')
local builder=ChainBuilder.new(Config)
local def=builder.create(model,j1,j2,endpoint,'Leg',{iterations=48,tolerance=0.02})
assert(def.Parent==nil and def.Name=='Leg' and def:GetAttribute('SchemaVersion')==1)
assert(def:GetAttribute('Iterations')==48 and def:GetAttribute('Tolerance')==0.02)
assert(not pcall(function() builder.create(model,j1,j2,endpoint,'Bad',{iterations=0,tolerance=0.1}) end))
assert(not pcall(function() builder.create(model,j1,j2,endpoint,'Bad',{iterations=1,tolerance=0.1,maxStepDegrees=181}) end))
assert(def.Endpoint.Value==endpoint and def.Joints.Joint001.Value==j1 and def.Joints.Joint002.Value==j2)
assert(def.Joints.Joint001:GetAttribute('Kind')=='Ball' and def.Joints.Joint002:GetAttribute('UpperDegrees')==90)
local container=Instance.new('Folder'); container.Name='EditRigIKChains'; container.Parent=model; def.Parent=container
local loaded=builder.readSettings(def)
assert(loaded.iterations==48 and loaded.tolerance==0.02 and loaded.maxStepDegrees==180)
builder.writeSettings(def,{iterations=12,tolerance=0.005,maxStepDegrees=25})
assert(def:GetAttribute('Iterations')==12 and def:GetAttribute('Tolerance')==0.005 and def:GetAttribute('MaxStepDegrees')==25)
assert(def.Endpoint.Value==endpoint and def.Joints.Joint001.Value==j1,'tuning must retain references and limits')
assert(not pcall(function() builder.writeSettings(def,{iterations=1,tolerance=0,maxStepDegrees=0}) end))
assert(def:GetAttribute('Iterations')==12 and def:GetAttribute('Tolerance')==0.005,'invalid input must not modify settings')
assert(not pcall(function() builder.writeSettings(container,{iterations=1,tolerance=0,maxStepDegrees=1}) end),'non-definition must be rejected')
def:SetAttribute('MaxStepDegrees',nil)
assert(builder.readSettings(def).maxStepDegrees==180,'legacy definition should load default')
assert(not pcall(function() builder.create(model,j2,j1,endpoint,'Bad') end),'reverse chain should fail')
local invalid=Instance.new('Attachment'); invalid.Parent=a
assert(not pcall(function() builder.create(model,j1,j2,invalid,'Bad') end),'endpoint must belong to end joint')
local bone1=Instance.new('Bone'); bone1.Parent=a; settings(bone1,'Ball')
local bone2=Instance.new('Bone'); bone2.Parent=bone1; settings(bone2,'Hinge')
local bend=Instance.new('Attachment'); bend.Parent=bone2
local bones=builder.create(model,bone1,bone2,bend,'Tail')
assert(bones.Joints.Joint001.Value==bone1 and bones.Joints.Joint002.Value==bone2)
local d=Instance.new('Part'); d.Parent=model
local finish=Instance.new('Motor6D'); finish.Part0=c; finish.Part1=d; finish.Parent=c; settings(finish,'Hinge')
local alternate=Instance.new('Motor6D'); alternate.Part0=b; alternate.Part1=c; alternate.Parent=b; settings(alternate,'Hinge')
local tip=Instance.new('Attachment'); tip.Parent=d
assert(not pcall(function() builder.create(model,j1,finish,tip,'Ambiguous') end),'multiple paths must be rejected')
local loop=Instance.new('Motor6D'); loop.Part0=b; loop.Part1=a; loop.Parent=b; settings(loop,'Hinge')
local after=Instance.new('Motor6D'); after.Part0=a; after.Part1=d; after.Parent=a; settings(after,'Hinge')
assert(not pcall(function() builder.create(model,j1,after,tip,'Cycle') end),'cyclic part chains must be rejected')
def:Destroy(); bones:Destroy(); model:Destroy()
return 'Chain builder selects Motor6D and Bone paths'
