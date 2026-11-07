local model=Instance.new('Model'); local p0=Instance.new('Part'); p0.Parent=model; local p1=Instance.new('Part'); p1.Parent=model
local motor=Instance.new('Motor6D'); motor.Name='Joint'; motor.Part0=p0; motor.Part1=p1; motor.Parent=p0
motor:SetAttribute('EditRigIK_SchemaVersion',1); motor:SetAttribute('EditRigIK_Kind','Hinge'); motor:SetAttribute('EditRigIK_Axis','Z')
motor:SetAttribute('EditRigIK_LowerDegrees',-180); motor:SetAttribute('EditRigIK_UpperDegrees',180); motor:SetAttribute('EditRigIK_SwingDegrees',90)
local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.xAxis; endpoint.Parent=p1
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local builder=ChainBuilder.new(Config); local def=builder.create(model,motor,motor,endpoint,'Arm',{iterations=10,tolerance=.001,baseMode='animated'}); def.Parent=folder
assert(builder.readSettings(def).baseMode=='animated','saved chain base mode must round trip')
local function open(options) return ChainDefinition.new(def,options,function(j,p,o) return ChainAdapter.new(j,p,o,Solver.new(Limits)) end) end
local chain=open({exclusive=true}); local base=CFrame.Angles(0,0,.3); motor.Transform=base
assert(chain:solve(Vector3.yAxis).converged,'saved animated mode must accept an updated base')
assert(#chain:destroy()==0 and motor.Transform:FuzzyEq(base,1e-5),'saved animated mode must restore the base')
motor.Transform=CFrame.identity; chain=open({exclusive=true,baseMode='fixed'}); motor.Transform=base
assert(not pcall(function() chain:solve(Vector3.yAxis) end),'explicit option must override saved mode')
chain:destroy(); motor.Transform=CFrame.identity
builder.writeSettings(def,{iterations=10,tolerance=.001,baseMode='fixed'}); assert(builder.readSettings(def).baseMode=='fixed')
def:SetAttribute('BaseMode',nil); assert(builder.readSettings(def).baseMode=='fixed','legacy definitions must remain strict')
def:SetAttribute('BaseMode','invalid'); assert(not pcall(open,{exclusive=true}),'invalid saved mode must be rejected')
assert(not pcall(builder.writeSettings,def,{iterations=10,tolerance=.001,baseMode='invalid'}),'invalid editor mode must be rejected')
model:Destroy()
return 'Authored chain base mode persists and permits explicit overrides'
