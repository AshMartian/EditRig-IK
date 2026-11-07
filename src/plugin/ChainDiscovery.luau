--!strict
-- Discover references only; does not modify the controller or its rig.
local ChainDiscovery={}
function ChainDiscovery.inspect(control)
 assert(typeof(control)=='Instance' and control:IsA('IKControl'),'select one IKControl')
 local model=control:FindFirstAncestorOfClass('Model')
 local root,effector=control.ChainRoot,control.EndEffector
 assert(model and root and effector and root:IsDescendantOf(model) and effector:IsDescendantOf(model),'IKControl root and end must belong to its model')
 local endpoint=if effector.ClassName=='Attachment' then effector else nil
 local pole=control.Pole
 if not pole or pole.ClassName~='Attachment' or not pole:IsDescendantOf(model) then pole=nil end
 local endJoint=if endpoint then endpoint.Parent else effector
 if endJoint:IsA('Motor6D') then endJoint=endJoint.Part1 end
 assert(endJoint,'end effector has no connected part')
 local path={}
 if root:IsA('Bone') then
  assert(endJoint:IsA('Bone'),'Bone root requires a Bone endpoint')
  local current=endJoint
  while current and current:IsA('Bone') do
   table.insert(path,1,current)
   assert(#path<=128,'chain too long')
   if current==root then break end
   current=current.Parent
  end
  assert(path[1]==root,'no direct Bone chain connects root and end')
 elseif root:IsA('BasePart') then
  assert(endJoint:IsA('BasePart'),'Motor6D root requires a part endpoint')
  local incoming,nextByPart={},{}
  for _,candidate in ipairs(model:GetDescendants()) do
   if candidate:IsA('Motor6D') and candidate.Enabled and candidate.Part0 and candidate.Part1 and candidate.Part0:IsDescendantOf(model) and candidate.Part1:IsDescendantOf(model) then
    if candidate.Part1==root then table.insert(incoming,candidate) end
    local list=nextByPart[candidate.Part0] or {}; nextByPart[candidate.Part0]=list; table.insert(list,candidate)
   end
  end
  assert(#incoming==1,'root part must have exactly one incoming enabled Motor6D')
  local found={}; local explored=0
  local function visit(part,joints,seen)
   explored+=1; assert(explored<=10000 and #joints<=128,'chain search exceeded safety limit')
   if part==endJoint then table.insert(found,table.clone(joints)); return end
   for _,joint in ipairs(nextByPart[part] or {}) do
    if not seen[joint.Part1] and #found<2 then
     seen[joint.Part1]=true; table.insert(joints,joint)
     visit(joint.Part1,joints,seen)
     table.remove(joints); seen[joint.Part1]=nil
    end
   end
  end
  visit(root,{incoming[1]},{[root]=true,[incoming[1].Part0]=true})
  assert(#found==1,if #found==0 then 'no directed Motor6D path connects root and end' else 'multiple Motor6D paths connect root and end')
  path=found[1]
 else error('only BasePart and Bone roots are supported') end
 return {model=model,joints=path,endpoint=endpoint,pole=pole}
end
return ChainDiscovery
