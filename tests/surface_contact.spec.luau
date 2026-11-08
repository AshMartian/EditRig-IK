local SurfaceContact = require('../src/runtime/SurfaceContact')
local function near(a,b) assert(math.abs(a-b)<1e-7, tostring(a)..' ~= '..tostring(b)) end
local function opts()
 return {origin={2,3,4},direction={0,-2,0},distance=5,up={0,4,0},maxSlopeDegrees=45,soleOffset=.2,supporting=true}
end
local sawCast=false
local r=SurfaceContact.probe(opts(),function(origin,delta)
 sawCast=true
 assert(origin[1]==2 and origin[2]==3 and origin[3]==4)
 near(delta[2],-5)
 return {position={2,0,4},normal={0,2,0}}
end)
assert(sawCast and r.status=='contact' and r.supporting)
near(r.slopeDegrees,0); near(r.normal[2],1); near(r.target[2],.2)
local noHit=SurfaceContact.probe(opts(),function() return nil end)
assert(noHit.status=='no contact' and noHit.supporting==false and noHit.target==nil)
local swing=opts(); swing.supporting=false
local hit=SurfaceContact.probe(swing,function() return {position={2,0,4},normal={0,1,0}} end)
assert(hit.status=='contact' and hit.supporting==false and hit.target~=nil,'a ray hit must not infer planting')
local steep=SurfaceContact.probe(opts(),function() return {position={2,0,4},normal={1,0,0}} end)
assert(steep.status=='excluded slope' and steep.supporting==false and steep.target==nil)
local invalid=SurfaceContact.probe(opts(),function() return {position={2,0,4},normal={0,0,0}} end)
assert(invalid.status=='invalid contact' and invalid.supporting==false and invalid.target==nil)
local tipped=opts(); tipped.up={1,0,0}; tipped.soleOffset=-.3
local tippedResult=SurfaceContact.probe(tipped,function() return {position={2,0,4},normal={1,0,0}} end)
assert(tippedResult.status=='contact'); near(tippedResult.slopeDegrees,0); near(tippedResult.target[1],1.7)
local boundary=opts(); boundary.maxSlopeDegrees=45
local edge=SurfaceContact.probe(boundary,function() return {position={2,0,4},normal={1,1,0}} end)
assert(edge.status=='contact','a surface exactly at the slope threshold is eligible')
for _,change in ipairs({
 function(o) o.origin={0/0,0,0} end,
 function(o) o.direction={0,0,0} end,
 function(o) o.up={0,0,0} end,
 function(o) o.distance=0 end,
 function(o) o.maxSlopeDegrees=91 end,
 function(o) o.soleOffset=math.huge end,
 function(o) o.supporting=nil end,
}) do
 local o=opts(); change(o)
 assert(not pcall(function() SurfaceContact.probe(o,function() return nil end) end),'invalid settings must be rejected')
end
print('surface contact tests passed')
