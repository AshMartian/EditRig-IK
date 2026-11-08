local geometry=LimitGeometry.new(Config)
local hinge=geometry.build({kind='Hinge',axis='Z',lower=-90,upper=90,swing=45})
assert(#hinge>3)
local start=hinge[1][1]; local finish=hinge[#hinge-2][2]
assert((start-Vector3.new(0,-1,0)).Magnitude<1e-5,'negative hinge bound')
assert((finish-Vector3.new(0,1,0)).Magnitude<1e-5,'positive hinge bound')
local cone=geometry.build({kind='Ball',axis='Y',lower=-20,upper=40,swing=60})
for i=1,48 do
 local point=cone[i][1]
 assert(math.abs(point.Magnitude-1)<1e-5 and math.abs(point:Dot(Vector3.yAxis)-.5)<1e-5,'swing cone half-angle')
end
assert(not pcall(function() geometry.build({kind='Ball',axis='Y',lower=40,upper=-20,swing=60}) end))
assert(LimitFrame,'LimitFrame fixture dependency is required')
local oriented=LimitGeometry.new(Config,LimitFrame)
local turn=math.pi/2
local quat={0,0,math.sin(turn/2),math.cos(turn/2)}
local rotation=CFrame.Angles(0,0,turn)
for _,kind in ipairs({'Hinge','Ball'}) do
 for _,axis in ipairs({'X','Y','Z'}) do
  local config={kind=kind,axis=axis,lower=-40,upper=65,swing=50}
  local base,baseTwist=geometry.build(config)
  local identity,identityTwist=oriented.build(config,{0,0,0,-2})
  local legacyIdentity=geometry.build(config,{0,0,0,2})
  assert(legacyIdentity[1][1]==base[1][1],'identity is allowed without the optional dependency')
  local rotated,rotatedTwist=oriented.build(config,quat)
  for _,set in ipairs({{base,identity,rotated},{baseTwist,identityTwist,rotatedTwist}}) do
   assert(#set[1]==#set[2] and #set[1]==#set[3],'frame rotation preserves geometry topology')
   for i=1,#set[1] do for p=1,2 do
    assert(set[1][i][p]==set[2][i][p],'identity frame preserves exact legacy geometry')
    assert((rotation:VectorToWorldSpace(set[1][i][p])-set[3][i][p]).Magnitude<1e-5,'rotated frame rotates the entire guide')
   end end
  end
 end
end
assert(not pcall(function() geometry.build({kind='Hinge',axis='X',lower=-20,upper=20,swing=0},quat) end),'rotated frame requires the LimitFrame dependency')
assert(not pcall(function() oriented.build({kind='Hinge',axis='X',lower=-20,upper=20,swing=0},{0,0,0,0}) end),'invalid limit frame is rejected')
assert(not pcall(function() geometry.build({kind='Hinge',axis='X',lower=-20,upper=20,swing=0},{0,0,0,0}) end),'zero frame is rejected without the dependency')
assert(not pcall(function() geometry.build({kind='Hinge',axis='X',lower=-20,upper=20,swing=0},{0,0,0,math.huge}) end),'nonfinite identity-like frame is rejected')
local wrapped=geometry.build({kind='Hinge',axis='Z',lower=150,upper=-150,swing=0,circular={start=150,width=60}})
local halfway=wrapped[24][2]
assert((halfway-Vector3.new(-1,0,0)).Magnitude<1e-5,'circular arc crosses the seam along its allowed 60 degree interval')
local unrestricted=geometry.build({kind='Hinge',axis='Z',lower=0,upper=0,swing=0,circular={start=0,width=360}})
assert((unrestricted[24][2]-Vector3.new(-1,0,0)).Magnitude<1e-5,'full revolution remains distinct from locked interval')
return 'Hinge arc and ball swing cone geometry passed'
