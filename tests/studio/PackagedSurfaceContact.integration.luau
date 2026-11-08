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
return 'Packaged runtime contact raycast passed'
