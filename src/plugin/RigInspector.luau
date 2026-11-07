--!strict
-- Read-only inventory, not an ownership lock or proof of exclusive access.
local RigInspector={}
function RigInspector.inspect(model,config)
 assert(typeof(model)=='Instance' and model:IsA('Model'),'select one model')
 assert(type(config)=='table' and type(config.validate)=='function','joint configuration validator required')
 local result={model=model:GetFullName(),motors=0,bones=0,animators=0,animationConstraints=0,enabledIK=0,ikControls={},configured=0,missingSettings=0,invalidSettings=0,disabledMotors=0,incompleteMotors=0,issues={}}
 local function issue(item,message) table.insert(result.issues,{path=item:GetFullName(),message=message}) end
 for _,item in ipairs(model:GetDescendants()) do
  if item:IsA('Motor6D') or item:IsA('Bone') then
   if item:IsA('Motor6D') then
    result.motors+=1
    if not item.Enabled then result.disabledMotors+=1; issue(item,'motor disabled') end
    if not item.Part0 or not item.Part1 or item.Part0==item.Part1 then result.incompleteMotors+=1; issue(item,'motor connections incomplete') end
   else result.bones+=1 end
   local version=item:GetAttribute('EditRigIK_SchemaVersion')
   if version==nil then result.missingSettings+=1; issue(item,'no IK settings')
   elseif version~=1 then result.invalidSettings+=1; issue(item,'unsupported settings version')
   else
    local valid=pcall(config.validate,{kind=item:GetAttribute('EditRigIK_Kind'),axis=item:GetAttribute('EditRigIK_Axis'),lower=item:GetAttribute('EditRigIK_LowerDegrees'),upper=item:GetAttribute('EditRigIK_UpperDegrees'),swing=item:GetAttribute('EditRigIK_SwingDegrees'),weight=item:GetAttribute('EditRigIK_Weight')})
    if valid then result.configured+=1 else result.invalidSettings+=1; issue(item,'invalid IK settings') end
   end
  elseif item:IsA('Animator') then result.animators+=1
  elseif item:IsA('AnimationConstraint') then result.animationConstraints+=1
  elseif item:IsA('IKControl') then
   if item.Enabled then result.enabledIK+=1 end
   table.insert(result.ikControls,{path=item:GetFullName(),enabled=item.Enabled})
  end
 end
 table.sort(result.ikControls,function(a,b) return a.path<b.path end)
 table.sort(result.issues,function(a,b) if a.path==b.path then return a.message<b.message end return a.path<b.path end)
 return result
end
function RigInspector.format(result)
 local lines={result.model, string.format('Motor6D: %d  |  Bone: %d  |  Animator: %d',result.motors,result.bones,result.animators),
  string.format('IKControls: %d (%d enabled)  |  AnimationConstraints: %d',#result.ikControls,result.enabledIK,result.animationConstraints),
  string.format('Joint settings: %d valid, %d missing, %d invalid',result.configured,result.missingSettings,result.invalidSettings),
  string.format('Motors: %d disabled, %d incomplete',result.disabledMotors,result.incompleteMotors)}
 for i=1,math.min(#result.ikControls,8) do
  local control=result.ikControls[i]
  table.insert(lines,control.path..' ('..(if control.enabled then 'enabled' else 'disabled')..')')
 end
 if #result.ikControls>8 then table.insert(lines,string.format('... and %d more IKControls',#result.ikControls-8)) end
 for i=1,math.min(#result.issues,8) do local entry=result.issues[i]; table.insert(lines,entry.path..': '..entry.message) end
 if #result.issues>8 then table.insert(lines,string.format('... and %d more joint issues',#result.issues-8)) end
 table.insert(lines,'Valid settings do not establish a usable chain or compatible direct-control actor.')
 table.insert(lines,'Inventory does not prove joint ownership is clear. Scripts, animation and controllers outside this model may also write joints.')
 if result.animationConstraints>0 then table.insert(lines,'AnimationConstraint joints are not supported by this prototype.') end
 return table.concat(lines,'\n')
end
return RigInspector
