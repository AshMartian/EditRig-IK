--!strict
-- Explicitly prepare Roblox IKControl hinge geometry without changing the rig.
local IKHingeBuilder={}
function IKHingeBuilder.new(Config)
 local api={}
 local orientations={X=CFrame.identity,Y=CFrame.Angles(0,0,math.pi/2),Z=CFrame.Angles(0,-math.pi/2,0)}
 local function partOf(attachment)
  if not attachment then return nil end
  return attachment:FindFirstAncestorWhichIsA('BasePart')
 end
 function api.prepare(joint)
  assert(typeof(joint)=='Instance' and joint:IsA('Motor6D') and joint.Parent,'select one parented Motor6D')
  local model=joint:FindFirstAncestorOfClass('Model')
  assert(model and joint.Enabled and joint.Part0 and joint.Part1 and joint.Part0~=joint.Part1 and joint.Part0:IsDescendantOf(model) and joint.Part1:IsDescendantOf(model),'motor must connect distinct parts in the same model')
  assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'save joint settings first')
  local config=Config.validate({kind=joint:GetAttribute('EditRigIK_Kind'),axis=joint:GetAttribute('EditRigIK_Axis'),lower=joint:GetAttribute('EditRigIK_LowerDegrees'),upper=joint:GetAttribute('EditRigIK_UpperDegrees'),swing=joint:GetAttribute('EditRigIK_SwingDegrees')})
  assert(config.kind=='Hinge','only Hinge Motor6D settings are supported')
  local p0,p1=joint.Part0,joint.Part1
  for _,item in ipairs(model:GetDescendants()) do
   if item:IsA('Constraint') then
    local a,b=partOf(item.Attachment0),partOf(item.Attachment1)
    assert(not ((a==p0 and b==p1) or (a==p1 and b==p0)),'a constraint already connects these parts')
   end
  end
  local name='EditRigIK_'..joint.Name
  assert(not p0:FindFirstChild(name..'_0') and not p1:FindFirstChild(name..'_1') and not p1:FindFirstChild(name..'_Hinge'),'generated names already exist')
  return {joint=joint,model=model,p0=p0,p1=p1,c0=joint.C0,c1=joint.C1,axis=config.axis,lower=config.lower,upper=config.upper,name=name}
 end
 function api.apply(prepared)
  assert(type(prepared)=='table','prepared hinge required')
  local current=api.prepare(prepared.joint)
  assert(current.model==prepared.model and current.p0==prepared.p0 and current.p1==prepared.p1 and current.c0==prepared.c0 and current.c1==prepared.c1 and current.axis==prepared.axis and current.lower==prepared.lower and current.upper==prepared.upper and current.name==prepared.name,'joint changed; prepare again')
  local a0=Instance.new('Attachment'); local a1=Instance.new('Attachment'); local hinge=Instance.new('HingeConstraint')
  local ok,err=pcall(function()
   a0.Name=current.name..'_0'; a0.CFrame=current.c0*orientations[current.axis]
   a1.Name=current.name..'_1'; a1.CFrame=current.c1*orientations[current.axis]
   hinge.Name=current.name..'_Hinge'; hinge.Attachment0=a0; hinge.Attachment1=a1
   hinge.LimitsEnabled=true; hinge.LowerAngle=current.lower; hinge.UpperAngle=current.upper
   a0.Parent=current.p0; a1.Parent=current.p1; hinge.Parent=current.p1
  end)
  if not ok then hinge:Destroy(); a0:Destroy(); a1:Destroy(); error(err) end
  return hinge
 end
 return api
end
return IKHingeBuilder
