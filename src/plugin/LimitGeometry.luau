--!strict
-- Lines are in the joint rest frame, in unit-length visualization space.
local LimitGeometry={}
function LimitGeometry.new(Config,LimitFrame)
 local api={}
 function api.build(input,frame)
  local config=Config.validate(input)
  local axes={X=Vector3.xAxis,Y=Vector3.yAxis,Z=Vector3.zAxis}
  local refs={X=Vector3.yAxis,Y=Vector3.zAxis,Z=Vector3.xAxis}
  local axis,reference=axes[config.axis],refs[config.axis]
  local tangent=axis:Cross(reference)
  if frame~=nil then
   local rotation
   if LimitFrame then
    rotation=LimitFrame.normalize(frame)
   else
    assert(type(frame)=='table' and #frame==4,'limit-frame rotation must have four components')
    for i=1,4 do
     assert(type(frame[i])=='number' and frame[i]==frame[i] and math.abs(frame[i])<math.huge,'limit-frame rotation must be finite')
    end
    assert(frame[4]~=0 or frame[1]~=0 or frame[2]~=0 or frame[3]~=0,'limit-frame rotation must be nonzero')
    assert(frame[1]==0 and frame[2]==0 and frame[3]==0,'LimitFrame dependency required for a rotated limit frame')
    rotation={0,0,0,1}
   end
   -- Keep the original Vector3 constants and arithmetic for identity frames.
   if rotation[1]~=0 or rotation[2]~=0 or rotation[3]~=0 then
    local basis=LimitFrame.basis(config.axis,rotation)
    axis=Vector3.new(basis.axis[1],basis.axis[2],basis.axis[3])
    reference=Vector3.new(basis.reference[1],basis.reference[2],basis.reference[3])
    tangent=Vector3.new(basis.tangent[1],basis.tangent[2],basis.tangent[3])
   end
  end
  local segments,twistSegments={},{}
  if config.kind=='Hinge' then
   local lower,upper=math.rad(config.lower),math.rad(config.upper)
   if config.circular then
    lower=math.rad(config.circular.start)
    upper=lower+math.rad(config.circular.width)
   end
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
   -- A separate ring encodes signed twist about the rest axis.  The
   -- perpendicular reference and positive direction match Limits.ball's
   -- right-handed twist convention; the offset separates it from the cone.
   local center=axis*1.3
   local function twistPoint(angle)
    return center+(reference*math.cos(angle)+tangent*math.sin(angle))*.6
   end
   local lower,upper=math.rad(config.lower),math.rad(config.upper)
   local start=twistPoint(lower)
   local last=start
   for i=1,48 do
    local nextPoint=twistPoint(lower+(upper-lower)*i/48)
    table.insert(twistSegments,{last,nextPoint}); last=nextPoint
   end
   table.insert(twistSegments,{center,start}); table.insert(twistSegments,{center,last})
   table.insert(twistSegments,{center,twistPoint(0)})
  end
  return segments,twistSegments
 end
 return api
end
return LimitGeometry
