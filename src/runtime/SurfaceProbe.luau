--!strict
-- Roblox raycast adapter. The source model is always excluded; callers must
-- explicitly add preview and temporary objects to the exclusion list.
local SurfaceProbe = {}
local function finite(x)
 return type(x)=='number' and x==x and math.abs(x)<math.huge
end
local function toVector(value)
 assert(type(value)=='table' and finite(value[1]) and finite(value[2]) and finite(value[3]),'finite three-number vector required')
 local result=Vector3.new(value[1],value[2],value[3])
 assert(finite(result.X) and finite(result.Y) and finite(result.Z),'vector exceeds Roblox numeric range')
 return result
end
function SurfaceProbe.new(worldRoot, sourceRig, extraExclusions)
 assert(typeof(worldRoot)=='Instance' and worldRoot:IsA('WorldRoot'),'WorldRoot required')
 assert(typeof(sourceRig)=='Instance' and sourceRig:IsA('Model'),'source rig model required')
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local dead=false
 local api={}
 function api:setExtraExclusions(extra)
  assert(not dead,'surface probe is destroyed')
  assert(type(extra)=='table','exclusion list required')
  local count=0
  for key, item in pairs(extra) do
   assert(type(key)=='number' and key>=1 and key%1==0 and typeof(item)=='Instance','exclusions must be an array of Instances')
   count+=1
  end
  local excluded={sourceRig}
  for index=1,count do
   assert(typeof(extra[index])=='Instance','exclusions must be a contiguous array of Instances')
   table.insert(excluded,extra[index])
  end
  params.FilterDescendantsInstances=excluded
 end
 function api:cast(origin,delta)
  assert(not dead,'surface probe is destroyed')
  local originVector=toVector(origin)
  local deltaVector=toVector(delta)
  assert(finite(deltaVector.Magnitude) and deltaVector.Magnitude>0 and deltaVector.Magnitude<=15000,'ray length must be greater than 0 and at most 15000 studs')
  local hit=worldRoot:Raycast(originVector,deltaVector,params)
  if hit==nil then return nil end
  return {position={hit.Position.X,hit.Position.Y,hit.Position.Z},normal={hit.Normal.X,hit.Normal.Y,hit.Normal.Z},instance=hit.Instance}
 end
 function api:destroy()
  if dead then return end
  dead=true
  params.FilterDescendantsInstances={}
 end
 api:setExtraExclusions(extraExclusions or {})
 return api
end
return SurfaceProbe
