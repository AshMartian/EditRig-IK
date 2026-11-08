local rig=Instance.new('Model')
local base=Instance.new('Part'); base.Parent=rig
local function joint(name)
 local part=Instance.new('Part'); part.Name=name..'Part'; part.Parent=rig
 local motor=Instance.new('Motor6D'); motor.Name=name; motor.Part0=base; motor.Part1=part; motor.Parent=base
 return motor
end
local saved=joint('Saved')
saved:SetAttribute('EditRigIK_SchemaVersion',1); saved:SetAttribute('EditRigIK_Kind','Hinge'); saved:SetAttribute('EditRigIK_Axis','X')
saved:SetAttribute('EditRigIK_LowerDegrees',-30); saved:SetAttribute('EditRigIK_UpperDegrees',45); saved:SetAttribute('EditRigIK_SwingDegrees',90)
local missing=joint('Missing')
local invalid=joint('Invalid'); invalid:SetAttribute('EditRigIK_SchemaVersion',1); invalid:SetAttribute('EditRigIK_Kind','invalid')
local holder=Instance.new('Folder')
local guides=SavedLimitOverlay.new(rig,holder,Config,AxisGizmo,LimitGeometry,1)
local shown,eligible=guides:update(nil)
assert(shown==1 and eligible==1,'only valid saved limits are drawn')
shown,eligible=guides:update(missing)
assert(shown==0 and eligible==1,'selecting another joint hides every model-wide limit guide')
shown,eligible=guides:update(rig)
assert(shown==1 and eligible==1,'selecting the model restores its model-wide limit guide')
local axisCount=0
for _,item in ipairs(holder:GetDescendants()) do if item.Name=='EditRigIKAxisX' then axisCount+=1 end end
assert(axisCount==0,'model-wide guides do not add per-joint axes')
local second=saved:Clone(); second.Name='SecondSaved'; second.Parent=base
task.wait()
shown,eligible=guides:update(nil)
assert(shown==1 and eligible==2,'valid saved guides are capped without hiding the total')
second:Destroy(); task.wait()
shown,eligible=guides:update(saved)
assert(shown==0 and eligible==1,'selected joint uses its separate draft guide')
for key,value in pairs({SchemaVersion=1,Kind='Ball',Axis='Y',LowerDegrees=-20,UpperDegrees=20,SwingDegrees=50}) do missing:SetAttribute('EditRigIK_'..key,value) end
task.wait()
shown,eligible=guides:update(nil)
assert(shown==1 and eligible==2,'draw count is capped even when more saved limits are valid')
missing:SetAttribute('EditRigIK_SchemaVersion',nil)
saved:SetAttribute('EditRigIK_UpperDegrees',-60)
task.wait()
shown,eligible=guides:update(nil)
assert(shown==0 and eligible==0,'invalidated saved metadata stops rendering')
-- Schema 2 saved circular hinges must retain their arc, including the seam.
local circular=joint('Circular')
for key,value in pairs({SchemaVersion=2,Kind='Hinge',Axis='Z',LowerDegrees=150,UpperDegrees=-150,SwingDegrees=90,CircularStartDegrees=150,CircularWidthDegrees=60}) do circular:SetAttribute('EditRigIK_'..key,value) end
task.wait()
shown,eligible=guides:update(nil)
assert(shown==1 and eligible==1,'valid circular schema 2 limit is shown')
local lastGeometry
local inspectGeometry={build=function(config) local a,b=LimitGeometry.build(config); lastGeometry=a; return a,b end}
local inspect=SavedLimitOverlay.new(rig,holder,Config,AxisGizmo,inspectGeometry,1)
inspect:update(nil)
assert(lastGeometry and (lastGeometry[24][2]-Vector3.new(-1,0,0)).Magnitude<1e-5,'saved circular arc follows the short interval through the seam')
circular:SetAttribute('EditRigIK_CircularWidthDegrees',nil); task.wait()
shown,eligible=guides:update(nil)
assert(shown==0 and eligible==0,'missing circular width fails closed')
circular:SetAttribute('EditRigIK_CircularWidthDegrees',400); task.wait()
shown,eligible=guides:update(nil)
assert(shown==0 and eligible==0,'out of range circular width fails closed')
circular:SetAttribute('EditRigIK_CircularWidthDegrees',50); task.wait()
shown,eligible=guides:update(nil)
assert(shown==0 and eligible==0,'circular endpoint mismatch fails closed')
circular:SetAttribute('EditRigIK_CircularWidthDegrees',60); circular:SetAttribute('EditRigIK_Kind','Ball'); task.wait()
shown,eligible=guides:update(nil)
assert(shown==0 and eligible==0,'schema 2 ball is rejected')
circular:SetAttribute('EditRigIK_Kind','Hinge'); circular:SetAttribute('EditRigIK_SchemaVersion',3); task.wait()
shown,eligible=guides:update(nil)
assert(shown==0 and eligible==0,'unknown schema fails closed')
inspect:destroy()
guides:destroy(); guides:destroy(); assert(#holder:GetChildren()==0,'cleanup removes model guides')
rig:Destroy(); holder:Destroy()
return 'Saved limit overlay validation and cleanup passed'
