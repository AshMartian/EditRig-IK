--!strict
-- Classify the displayed limit values independently from other actor settings.
local LimitDraft={}
local names={kind='EditRigIK_Kind',axis='EditRigIK_Axis',lower='EditRigIK_LowerDegrees',upper='EditRigIK_UpperDegrees',swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
function LimitDraft.new(Config)
 local api={}
 function api.classify(joint,input)
  if not joint then return 'none' end
  local inputOk,displayed=pcall(Config.validate,input)
  if not inputOk then return 'invalid' end
  local stored={}
  local any=joint:GetAttribute('EditRigIK_SchemaVersion')~=nil
  for key,name in pairs(names) do
   stored[key]=joint:GetAttribute(name)
   if stored[key]~=nil then any=true end
  end
  if not any then return 'unconfigured' end
  if joint:GetAttribute('EditRigIK_SchemaVersion')~=1 then return 'invalidSaved' end
  local savedOk,saved=pcall(Config.validate,stored)
  if not savedOk then return 'invalidSaved' end
  for key,value in pairs(saved) do if displayed[key]~=value then return 'draft' end end
  return 'saved'
 end
 return api
end
return LimitDraft
