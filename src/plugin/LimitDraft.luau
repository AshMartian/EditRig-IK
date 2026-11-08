--!strict
-- Classify the displayed limit values independently from other actor settings.
local LimitDraft={}
local names={kind='EditRigIK_Kind',axis='EditRigIK_Axis',lower='EditRigIK_LowerDegrees',upper='EditRigIK_UpperDegrees',swing='EditRigIK_SwingDegrees',weight='EditRigIK_Weight'}
function LimitDraft.new(Config)
 local api={}
 function api.classify(joint,input,started)
  if not joint then return 'none' end
  local inputOk,displayed=pcall(Config.validate,input)
  if not inputOk then return 'invalid' end
  local stored={}
  local any=joint:GetAttribute('EditRigIK_SchemaVersion')~=nil
  for key,name in pairs(names) do
   stored[key]=joint:GetAttribute(name)
   if stored[key]~=nil then any=true end
  end
  if not any then return if started then 'draft' else 'unconfigured' end
  local version=joint:GetAttribute('EditRigIK_SchemaVersion')
  if version~=1 and version~=2 then return 'invalidSaved' end
  if version==2 then stored.circular={start=joint:GetAttribute('EditRigIK_CircularStartDegrees'),width=joint:GetAttribute('EditRigIK_CircularWidthDegrees')} end
  local savedOk,saved=pcall(Config.validate,stored)
  if not savedOk then return 'invalidSaved' end
  for key,value in pairs(saved) do
   if key=='circular' then
    if not displayed.circular or displayed.circular.start~=value.start or displayed.circular.width~=value.width then return 'draft' end
   elseif displayed[key]~=value then return 'draft' end
  end
  if displayed.circular and not saved.circular then return 'draft' end
  return 'saved'
 end
 return api
end
return LimitDraft
