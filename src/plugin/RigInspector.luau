--!strict
-- Read-only inventory, not an ownership lock or proof of exclusive access.
local RigInspector={}
function RigInspector.inspect(model)
 assert(typeof(model)=='Instance' and model:IsA('Model'),'select one model')
 local result={model=model:GetFullName(),motors=0,bones=0,animators=0,animationConstraints=0,enabledIK=0,ikControls={}}
 for _,item in ipairs(model:GetDescendants()) do
  if item:IsA('Motor6D') then result.motors+=1
  elseif item:IsA('Bone') then result.bones+=1
  elseif item:IsA('Animator') then result.animators+=1
  elseif item:IsA('AnimationConstraint') then result.animationConstraints+=1
  elseif item:IsA('IKControl') then
   if item.Enabled then result.enabledIK+=1 end
   table.insert(result.ikControls,{path=item:GetFullName(),enabled=item.Enabled})
  end
 end
 table.sort(result.ikControls,function(a,b) return a.path<b.path end)
 return result
end
function RigInspector.format(result)
 local lines={result.model, string.format('Motor6D: %d  |  Bone: %d  |  Animator: %d',result.motors,result.bones,result.animators),
  string.format('IKControls: %d (%d enabled)  |  AnimationConstraints: %d',#result.ikControls,result.enabledIK,result.animationConstraints)}
 for i=1,math.min(#result.ikControls,8) do
  local control=result.ikControls[i]
  table.insert(lines,control.path..' ('..(if control.enabled then 'enabled' else 'disabled')..')')
 end
 if #result.ikControls>8 then table.insert(lines,string.format('... and %d more IKControls',#result.ikControls-8)) end
 table.insert(lines,'Inventory does not prove joint ownership is clear. Scripts, animation and controllers outside this model may also write joints.')
 if result.animationConstraints>0 then table.insert(lines,'AnimationConstraint joints are not supported by this prototype.') end
 return table.concat(lines,'\n')
end
return RigInspector
