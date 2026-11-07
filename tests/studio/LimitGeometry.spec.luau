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
return 'Hinge arc and ball swing cone geometry passed'
