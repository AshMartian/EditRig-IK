--!strict
-- Experimental, opt-in circular hinge math used by schema-3 configured chains.
-- Editor authoring, ghost preview, and built-in constraints do not yet use it.
-- Angles are radians. An interval is {start, width} traversed positively;
-- width 0 is locked and width 2*pi is unrestricted. Quaternion order is xyzw.
local CircularHinge={}
local v1={}
local turn=2*math.pi
local epsilon=1e-12
local function finite(value)
 return type(value)=='number' and value==value and math.abs(value)<math.huge
end
local function canonical(angle)
 local value=(angle+math.pi)%turn-math.pi
 if math.abs(math.abs(value)-math.pi)<epsilon then return -math.pi end
 return value
end
local function normalized(values,count,name)
 assert(type(values)=='table' and #values==count,name..' must have '..count..' components')
 local max=0
 for i=1,count do
  assert(finite(values[i]),name..' must be finite')
  max=math.max(max,math.abs(values[i]))
 end
 assert(max>0,name..' must be nonzero')
 local result={}; local sum=0
 for i=1,count do result[i]=values[i]/max; sum+=result[i]*result[i] end
 local length=math.sqrt(sum)
 for i=1,count do result[i]/=length end
 return result
end
local function validated(interval)
 assert(type(interval)=='table' and finite(interval.start) and finite(interval.width),'finite circular interval required')
 assert(interval.width>=0 and interval.width<=turn,'interval width must be between zero and one revolution')
 return canonical(interval.start),interval.width
end
function v1.new(start,width)
 local a,b=validated({start=start,width=width})
 return {start=a,width=b}
end
function v1.clamp(interval,angle)
 local start,width=validated(interval)
 assert(finite(angle),'finite angle required')
 local value=canonical(angle)
 if width==turn then return value end
 local offset=(value-start)%turn
 if offset<=width then return value end
 -- Choose the closest boundary along the circle. Exact ties use the start.
 local distanceToEnd=offset-width
 local distanceToStart=turn-offset
 if distanceToEnd+epsilon<distanceToStart then return canonical(start+width) end
 return start
end
function v1.hinge(rotation,axis,interval)
 local q=normalized(rotation,4,'rotation')
 local a=normalized(axis,3,'axis')
 local projection=q[1]*a[1]+q[2]*a[2]+q[3]*a[3]
 -- At an exact 180-degree perpendicular swing, twist is undefined. Match
 -- legacy Limits.hinge by choosing zero before applying the interval.
 local angle=if math.sqrt(projection*projection+q[4]*q[4])<epsilon then 0 else 2*math.atan2(projection,q[4])
 local half=v1.clamp(interval,angle)/2
 return {a[1]*math.sin(half),a[2]*math.sin(half),a[3]*math.sin(half),math.cos(half)}
end
CircularHinge.v1=v1
return CircularHinge
