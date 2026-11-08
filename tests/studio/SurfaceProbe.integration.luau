-- Executed with SurfaceProbe and SurfaceContact loaded by the Studio fixture harness.
local parent = Instance.new('Folder')
parent.Name = 'EditRigIKSurfaceProbeFixture'
parent.Parent = workspace
local ok, failure = pcall(function()
local source = Instance.new('Model'); source.Name='Source'; source.Parent=parent
local ghost = Instance.new('Model'); ghost.Name='Ghost'; ghost.Parent=parent
local function plate(owner, y)
 local part=Instance.new('Part'); part.Anchored=true; part.Size=Vector3.new(6,1,6)
 part.Position=Vector3.new(13000,y,13000); part.Parent=owner; return part
end
local sourcePlate=plate(source,13006)
local ghostPlate=plate(ghost,13004)
local ground=plate(parent,13000)
local probe=SurfaceProbe.new(workspace,source,{ghost})
local options={origin={13000,13010,13000},direction={0,-1,0},up={0,1,0},distance=20,maxSlopeDegrees=45,soleOffset=.25,supporting=false}
local function cast(origin,delta) return probe:cast(origin,delta) end
local r=SurfaceContact.probe(options,cast)
assert(r.status=='contact' and r.instance==ground and r.supporting==false,'source and ghost must be excluded and a hit must not infer support')
assert(math.abs(r.target[2]-13000.75)<1e-4)
probe:setExtraExclusions({})
r=SurfaceContact.probe(options,cast)
assert(r.instance==ghostPlate,'changing temporary exclusions must affect subsequent casts')
probe:setExtraExclusions({ghost})
r=SurfaceContact.probe(options,cast)
assert(r.instance==ground,'the source exclusion must survive updates')
assert(not pcall(function() probe:setExtraExclusions({false}) end),'invalid exclusions must be rejected')
assert(SurfaceContact.probe(options,cast).instance==ground,'a rejected exclusion update must preserve the existing filter')
assert(not pcall(function() probe:cast({0,0,0},{0,0,0}) end),'zero direction must be rejected')
assert(not pcall(function() probe:cast({0,0,0},{0,-15001,0}) end),'Roblox rays cannot exceed 15000 studs')
probe:destroy()
assert(not pcall(function() probe:cast({0,0,0},{0,-1,0}) end),'destroyed probe must not be used')
end)
parent:Destroy()
assert(ok, tostring(failure))
return 'surface probe integration passed'
