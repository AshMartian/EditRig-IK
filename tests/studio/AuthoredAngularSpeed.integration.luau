local model=Instance.new('Model'); local root=Instance.new('Part'); root.Parent=model
local motor=Instance.new('Motor6D'); local tipPart=Instance.new('Part'); tipPart.Parent=model
motor.Part0=root; motor.Part1=tipPart; motor.Parent=root
motor:SetAttribute('EditRigIK_SchemaVersion',1); motor:SetAttribute('EditRigIK_Kind','Hinge'); motor:SetAttribute('EditRigIK_Axis','Z')
motor:SetAttribute('EditRigIK_LowerDegrees',-180); motor:SetAttribute('EditRigIK_UpperDegrees',180); motor:SetAttribute('EditRigIK_SwingDegrees',90)
local tip=Instance.new('Attachment'); tip.Position=Vector3.xAxis; tip.Parent=tipPart
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local builder=ChainBuilder.new(Config)
local def=builder.create(model,motor,motor,tip,'Arm',{iterations=10,tolerance=.001,maxSpeedDegrees=90}); def.Parent=folder
assert(builder.readSettings(def).maxSpeedDegrees==90,'authored speed must round trip')
local function open() return ChainDefinition.new(def,{exclusive=true},function(j,p,o) return ChainAdapter.new(j,p,o,Solver.new(Limits)) end) end
local chain=open()
assert(not pcall(function() chain:solve(Vector3.yAxis) end),'capped chains must require dt')
local result=chain:solve(Vector3.yAxis,{dt=.25})
assert(result.motionLimited and motor.Transform:FuzzyEq(CFrame.Angles(0,0,math.rad(22.5)),1e-5),'saved speed must cap configured chain')
chain:destroy(); chain=open()
assert(chain:solve(Vector3.yAxis,{maxAngularSpeed=0}).converged,'preview-style override must disable speed cap')
chain:destroy(); builder.writeSettings(def,{iterations=10,tolerance=.001,maxSpeedDegrees=0})
chain=open(); assert(chain:solve(Vector3.yAxis,{dt=.1}).converged,'uncapped chain accepts dt from generic update loops'); chain:destroy()
def:SetAttribute('MaxSpeedDegrees',nil); assert(builder.readSettings(def).maxSpeedDegrees==0,'legacy chains must be uncapped')
assert(not pcall(builder.writeSettings,def,{iterations=10,tolerance=.001,maxSpeedDegrees=-1}),'negative speed rejected')
model:Destroy()
return 'Authored speed persists and reaches configured chains'
