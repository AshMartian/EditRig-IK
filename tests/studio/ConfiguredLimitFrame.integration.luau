-- Inject ChainDefinition, LimitFrame, Limits, Solver and ChainAdapter.
local model=Instance.new('Model')
local base=Instance.new('Part'); base.Parent=model
local tip=Instance.new('Part'); tip.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=base; motor.Part1=tip; motor.Parent=base
local bone=Instance.new('Bone'); bone.Parent=base
local function definition(joint,endpointParent)
 local folder=Instance.new('Folder'); folder.Parent=model
 local def=Instance.new('Folder'); def.Parent=folder
 def:SetAttribute('SchemaVersion',1); def:SetAttribute('Iterations',40); def:SetAttribute('Tolerance',.01)
 local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.new(1,0,0); endpoint.Parent=endpointParent
 local endRef=Instance.new('ObjectValue'); endRef.Name='Endpoint'; endRef.Value=endpoint; endRef.Parent=def
 local refs=Instance.new('Folder'); refs.Name='Joints'; refs.Parent=def
 local ref=Instance.new('ObjectValue'); ref.Name='Joint001'; ref.Value=joint; ref.Parent=refs
 ref:SetAttribute('Order',1); ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','X')
 ref:SetAttribute('LowerDegrees',-20); ref:SetAttribute('UpperDegrees',30); ref:SetAttribute('SwingDegrees',90)
 return def,ref
end
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b)) end
local function setFrame(ref,q)
 for i,key in ipairs({'FrameX','FrameY','FrameZ','FrameW'}) do ref:SetAttribute(key,q[i]) end
end
local function capture(def,frame)
 local captured
 local chain=ChainDefinition.new(def,{exclusive=true},function(_,_,options)
  captured=options.limits[1]
  return {solve=function() end,destroy=function() return {} end}
 end,frame)
 chain:destroy()
 return captured
end
for _,entry in ipairs({{motor,tip},{bone,bone}}) do
 local def,ref=definition(entry[1],entry[2])
 -- Legacy readers and legacy definitions retain the exact cardinal axis even
 -- if extraneous frame attributes were attached to the old schema.
 setFrame(ref,{0,0,0,0})
 local legacy=capture(def,nil)
 assert(legacy.axis[1]==1 and legacy.axis[2]==0 and legacy.axis[3]==0,'schema 1 must preserve cardinal-axis semantics')
 def:SetAttribute('SchemaVersion',2)
 local half=math.pi/8
 setFrame(ref,{0,0,math.sin(half),math.cos(half)})
 assert(not pcall(function() capture(def,nil) end),'schema 2 must require frame dependency')
 local tilted=capture(def,LimitFrame)
 near(tilted.axis[1],math.sqrt(.5)); near(tilted.axis[2],math.sqrt(.5)); near(tilted.axis[3],0)
 local turn=math.rad(60)/2
 local clamped=Limits.hinge({tilted.axis[1]*math.sin(turn),tilted.axis[2]*math.sin(turn),0,math.cos(turn)},tilted.axis,tilted.lower,tilted.upper)
 near(clamped[1],math.sqrt(.5)*math.sin(math.rad(15))); near(clamped[2],clamped[1])
 local actual=ChainDefinition.new(def,{exclusive=true},function(joints,point,options)
  return ChainAdapter.new(joints,point,options,Solver.new(Limits))
 end,LimitFrame)
 local axis=Vector3.new(math.sqrt(.5),math.sqrt(.5),0)
 local target=CFrame.fromAxisAngle(axis,math.rad(60)):PointToWorldSpace(Vector3.xAxis)
 local result=actual:solve(target)
 local observedAxis,observedAngle=entry[1].Transform.Rotation:ToAxisAngle()
 assert(result.error>.01 and math.abs(observedAngle-math.rad(30))<1e-3,'configured solver must enforce the tilted hinge limit')
 assert((observedAxis-axis).Magnitude<1e-3,'configured solver must rotate about the tilted axis')
 actual:destroy()
 for _,bad in ipairs({{0,0,0,0},{0,0,0,'invalid'}}) do
  setFrame(ref,bad)
  assert(not pcall(function() capture(def,LimitFrame) end),'invalid schema 2 frame must be rejected before creating a chain')
 end
 setFrame(ref,{0,0,0,1}); ref:SetAttribute('FrameY',nil)
 assert(not pcall(function() capture(def,LimitFrame) end),'missing schema 2 frame components must be rejected')
 local created=false
 assert(not pcall(function() ChainDefinition.new(def,{exclusive=true},function() created=true end,LimitFrame) end) and not created,'invalid frames must not acquire chain ownership')
 def:SetAttribute('SchemaVersion',3)
 assert(not pcall(function() capture(def,LimitFrame) end),'unknown schema must fail closed')
end
model:Destroy()
return 'configured limit frame schema tests passed'
