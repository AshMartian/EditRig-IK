--!strict
-- Lines are in the joint rest frame, in unit-length visualization space.
local LimitGeometry={}
function LimitGeometry.new(Config)
 local api={}
 function api.build(input)
  local config=Config.validate(input)
  local axes={X=Vector3.xAxis,Y=Vector3.yAxis,Z=Vector3.zAxis}
  local refs={X=Vector3.yAxis,Y=Vector3.zAxis,Z=Vector3.xAxis}
  local axis,reference=axes[config.axis],refs[config.axis]
  local tangent=axis:Cross(reference)
  local segments={}
  if config.kind=='Hinge' then
   local lower,upper=math.rad(config.lower),math.rad(config.upper)
   local function point(angle) return reference*math.cos(angle)+tangent*math.sin(angle) end
   local start=point(lower)
   local previous=start
   for i=1,48 do
    local nextPoint=point(lower+(upper-lower)*i/48)
    table.insert(segments,{previous,nextPoint}); previous=nextPoint
   end
   table.insert(segments,{Vector3.zero,start}); table.insert(segments,{Vector3.zero,previous})
  else
   local swing=math.rad(config.swing)
   local function point(angle)
    return axis*math.cos(swing)+(reference*math.cos(angle)+tangent*math.sin(angle))*math.sin(swing)
   end
   local previous=point(0)
   for i=1,48 do
    local nextPoint=point(2*math.pi*i/48)
    table.insert(segments,{previous,nextPoint}); previous=nextPoint
   end
   for i=0,3 do table.insert(segments,{Vector3.zero,point(math.pi*i/2)}) end
  end
  return segments
 end
 return api
end
return LimitGeometry
