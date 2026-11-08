-- Runtime and fixtureFolder are supplied by the packaged-runtime harness.
assert(type(Runtime.SurfaceContact.probe)=='function' and type(Runtime.SurfaceProbe.new)=='function', 'packaged runtime must expose contact modules')
local source=Instance.new('Model'); source.Name='Source'; source.Parent=fixtureFolder
local ghost=Instance.new('Model'); ghost.Name='Ghost'; ghost.Parent=fixtureFolder
local function plate(owner,y)
 local part=Instance.new('Part'); part.Anchored=true; part.Size=Vector3.new(6,1,6)
 part.Position=Vector3.new(13000,y,13000); part.Parent=owner; return part
end
plate(source,13006)
local ghostPlate=plate(ghost,13004)
local ground=plate(fixtureFolder,13000)
local probe=Runtime.SurfaceProbe.new(workspace,source,{ghost})
local options={origin={13000,13010,13000},direction={0,-1,0},up={0,1,0},distance=20,maxSlopeDegrees=45,soleOffset=.25,supporting=false}
local function cast(origin,delta) return probe:cast(origin,delta) end
local contact=Runtime.SurfaceContact.probe(options,cast)
assert(contact.status=='contact' and not contact.supporting and contact.instance==ground,'packaged modules must exclude source and ghost and preserve explicit support state')
assert(math.abs(contact.target[2]-13000.75)<1e-4, 'packaged contact must calculate the sole target')
probe:setExtraExclusions({})
contact=Runtime.SurfaceContact.probe(options,cast)
assert(contact.instance==ghostPlate, 'packaged probe must update exclusion filters')
probe:destroy()
local base=Instance.new('Part'); base.Anchored=true; base.Parent=source
local tip=Instance.new('Part'); tip.Anchored=true; tip.Parent=source
local joint=Instance.new('Motor6D'); joint.Part0=base; joint.Part1=tip; joint.Parent=base
local chain=Runtime.createIKChain({joint},Vector3.xAxis,{exclusive=true})
local desired=CFrame.Angles(0,0,math.rad(30))
local solved=chain:solve(desired:PointToWorldSpace(Vector3.xAxis),{iterations=80,tolerance=.002,targetOrientation=desired,orientationTolerance=.002})
assert(solved.converged and solved.orientationConverged,'packaged runtime must solve endpoint orientation')
local frame=Runtime.SurfaceOrientation.align(CFrame.identity,Vector3.yAxis,-Vector3.zAxis,Vector3.yAxis,1)
assert(frame and frame.rotation:FuzzyEq(CFrame.identity,1e-5),'packaged runtime must expose the surface orientation adapter')
chain:destroy()
joint.Transform=CFrame.identity
local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.xAxis; endpoint.Parent=tip
local folder=Instance.new('Folder'); folder.Parent=source
local definition=Instance.new('Folder'); definition.Parent=folder
definition:SetAttribute('SchemaVersion',3); definition:SetAttribute('Iterations',40); definition:SetAttribute('Tolerance',.01)
local endRef=Instance.new('ObjectValue'); endRef.Name='Endpoint'; endRef.Value=endpoint; endRef.Parent=definition
local list=Instance.new('Folder'); list.Name='Joints'; list.Parent=definition
local ref=Instance.new('ObjectValue'); ref.Value=joint; ref.Parent=list
ref:SetAttribute('Order',1); ref:SetAttribute('Kind','Hinge'); ref:SetAttribute('Axis','Z'); ref:SetAttribute('SwingDegrees',90)
ref:SetAttribute('FrameX',0); ref:SetAttribute('FrameY',0); ref:SetAttribute('FrameZ',0); ref:SetAttribute('FrameW',1)
ref:SetAttribute('CircularStartDegrees',170); ref:SetAttribute('CircularWidthDegrees',40)
local wrapped=Runtime.createConfiguredIKChain(definition,{exclusive=true})
assert(wrapped:solve(-Vector3.xAxis).error<.01,'packaged runtime must solve through wrapped 180-degree interval')
assert(wrapped:solve(Vector3.xAxis).error>.5,'packaged runtime must enforce wrapped interval')
wrapped:destroy()
return 'Packaged runtime contact, orientation and circular hinge passed'
