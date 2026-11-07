--!strict
-- Discover references only; does not modify the controller or its rig.
local ChainDiscovery={}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function ChainDiscovery.parseOffset(text)
 assert(type(text)=='string','enter three numeric offsets separated by commas')
 local sx,sy,sz=string.match(text,'^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$')
 local x,y,z=if sx then tonumber(sx) else nil,if sy then tonumber(sy) else nil,if sz then tonumber(sz) else nil
 assert(finite(x) and finite(y) and finite(z),'enter three finite numeric offsets separated by commas')
 return Vector3.new(x,y,z)
end
function ChainDiscovery.prepareEndpoint(last,offset)
 assert(typeof(last)=='Instance' and (last:IsA('Motor6D') or last:IsA('Bone')),'capture an end joint first')
 assert(typeof(offset)=='Vector3' and finite(offset.X) and finite(offset.Y) and finite(offset.Z),'endpoint offset must be a finite Vector3')
 local model=last:FindFirstAncestorOfClass('Model')
 local parent=if last:IsA('Motor6D') then last.Part1 else last
 assert(model and parent and parent:IsDescendantOf(model),'end joint and endpoint parent must belong to a model')
 assert(not parent:FindFirstChild('EditRigIKEndpoint'),'EditRigIKEndpoint already exists; select it or rename it')
 local link=if last:IsA('Motor6D') then last.C1:Inverse():PointToWorldSpace(offset) else offset
 assert(link.Magnitude>1e-7,'endpoint creates a zero-length last link; choose another offset')
 local attachment=Instance.new('Attachment')
 attachment.Name='EditRigIKEndpoint'; attachment.Position=offset
 return attachment,parent
end
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
function ChainDiscovery.verifyCapture(control,capture)
 assert(type(capture)=='table' and type(capture.joints)=='table','capture an IKControl chain first')
 local current=ChainDiscovery.inspect(control)
 assert(current.model==capture.model and #current.joints==#capture.joints,'IKControl chain changed; capture it again')
 for i,joint in ipairs(current.joints) do
  assert(joint==capture.joints[i],'IKControl chain changed; capture it again')
 end
 return current.joints
end
return ChainDiscovery
