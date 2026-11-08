--!strict
-- Degree-space helpers for an editable positively swept circular interval.
local Draft={}
local function finite(value)
 return type(value)=='number' and value==value and math.abs(value)<math.huge
end
local function canonical(value)
 return (value+180)%360-180
end
local function validate(interval)
 assert(type(interval)=='table' and finite(interval.start) and interval.start>=-180 and interval.start<180 and finite(interval.width) and interval.width>=0 and interval.width<=360,'invalid circular interval')
end
function Draft.endpoint(interval)
 validate(interval)
 return canonical(interval.start+interval.width)
end
function Draft.setBound(interval,bound,value)
 validate(interval)
 assert((bound=='lower' or bound=='upper') and finite(value) and value>=-180 and value<=180,'invalid bound')
 value=canonical(value)
 local oldEnd=Draft.endpoint(interval)
 local start=if bound=='lower' then value else interval.start
 local endpoint=if bound=='upper' then value else oldEnd
 local width=(endpoint-start)%360
 if width==0 and interval.width==360 then width=360 end
 return {start=start,width=width}
end
function Draft.shift(interval,offset)
 validate(interval)
 assert(finite(offset),'invalid offset')
 return {start=canonical(interval.start+offset),width=interval.width}
end
return Draft
