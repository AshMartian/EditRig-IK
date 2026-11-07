--!strict
-- Per-runtime claims; not a lock against Animator, scripts, or other runtimes.
local Ownership={}
function Ownership.new()
 local claims=setmetatable({}, {__mode='k'})
 local api={}
 function api:acquire(joints)
  local seen={}
  for _,joint in ipairs(joints) do
   assert(not seen[joint] and not claims[joint],'joint is already owned by this runtime')
   seen[joint]=true
  end
  local token={}
  for joint in pairs(seen) do claims[joint]=token end
  local released=false
  return function()
   if released then return end
   released=true
   for joint in pairs(seen) do if claims[joint]==token then claims[joint]=nil end end
  end
 end
 return api
end
return Ownership
