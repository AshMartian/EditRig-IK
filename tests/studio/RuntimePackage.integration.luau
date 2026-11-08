-- RuntimeSource and RuntimeComponents are supplied by the source-level test harness.
assert(type(RuntimeComponents.LimitFrame)=='string' and #RuntimeComponents.LimitFrame>0,'runtime source map must include LimitFrame')
assert(type(RuntimeComponents.CircularHinge)=='string' and #RuntimeComponents.CircularHinge>0,'runtime source map must include CircularHinge')
local storage=Instance.new('Folder')
local bundle=Instance.new('ModuleScript'); bundle.Name='RuntimeBundle'; bundle.Source=RuntimeSource
for name,source in pairs(RuntimeComponents) do
 local child=Instance.new('ModuleScript'); child.Name=name; child.Source=source; child.Parent=bundle
end
local copy=RuntimeInstaller.prepare(storage,bundle); copy.Parent=storage
local runtime=require(copy)
local identity={0,0,0,1}
local solved=runtime.solve({root={0,0,0},joints={{rest=identity,rotation=identity,offset={1,0,0}}}},{0,1,0},{iterations=5,tolerance=.001})
assert(solved.converged and solved.error<.001,'installed cloned runtime must be requireable and solve')
assert(type(runtime.createFootstepChain)=='function' and type(runtime.createActor)=='function','installed API must include actor and footstep factories')
assert(type(runtime.InputBindings.new)=='function','installed runtime must include InputAction bindings')
assert(type(runtime.createTargetStepper)=='function','installed runtime must include target stepper')
assert(type(runtime.BallDrive.new)=='function','installed runtime must include ball-joint behavior')
local model=Instance.new('Model')
local base=Instance.new('Part'); base.Parent=model
local tip=Instance.new('Part'); tip.Parent=model
local joint=Instance.new('Motor6D'); joint.Part0=base; joint.Part1=tip; joint.Parent=base
local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.xAxis; endpoint.Parent=tip
local folder=Instance.new('Folder'); folder.Parent=model
local definition=Instance.new('Folder'); definition.Parent=folder
definition:SetAttribute('SchemaVersion',2); definition:SetAttribute('Iterations',40); definition:SetAttribute('Tolerance',.01)
local endRef=Instance.new('ObjectValue'); endRef.Name='Endpoint'; endRef.Value=endpoint; endRef.Parent=definition
local list=Instance.new('Folder'); list.Name='Joints'; list.Parent=definition
local ref=Instance.new('ObjectValue'); ref.Value=joint; ref.Parent=list
ref:SetAttribute('Order',1); ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','X')
ref:SetAttribute('LowerDegrees',-20); ref:SetAttribute('UpperDegrees',30); ref:SetAttribute('SwingDegrees',90)
ref:SetAttribute('FrameX',0); ref:SetAttribute('FrameY',0); ref:SetAttribute('FrameZ',math.sin(math.pi/8)); ref:SetAttribute('FrameW',math.cos(math.pi/8))
local chain=runtime.createConfiguredIKChain(definition,{exclusive=true})
local axis=Vector3.new(math.sqrt(.5),math.sqrt(.5),0)
local target=CFrame.fromAxisAngle(axis,math.rad(60)):PointToWorldSpace(Vector3.xAxis)
local result=chain:solve(target)
local observed,angle=joint.Transform.Rotation:ToAxisAngle()
assert(result.error>.01 and math.abs(angle-math.rad(30))<1e-3 and (observed-axis).Magnitude<1e-3,'installed runtime must enforce schema 2 tilted hinge limits')
chain:destroy()
joint.Transform=CFrame.identity
ref:SetAttribute('Axis','Z'); ref:SetAttribute('FrameZ',0); ref:SetAttribute('FrameW',1)
ref:SetAttribute('LowerDegrees',nil); ref:SetAttribute('UpperDegrees',nil)
ref:SetAttribute('CircularStartDegrees',170); ref:SetAttribute('CircularWidthDegrees',40)
definition:SetAttribute('SchemaVersion',3)
local wrapped=runtime.createConfiguredIKChain(definition,{exclusive=true})
local wrappedResult=wrapped:solve(Vector3.new(-1,0,0))
assert(wrappedResult.error<.01,'installed runtime must solve through the wrapped 180-degree interval')
local blocked=wrapped:solve(Vector3.xAxis)
assert(blocked.error>.5,'installed runtime must enforce the wrapped interval')
wrapped:destroy(); model:Destroy()
assert(not pcall(function() RuntimeInstaller.prepare(storage,bundle) end),'second installation must not overwrite')
storage:Destroy(); bundle:Destroy()
return 'Cloned runtime package loads and solves in Studio'
