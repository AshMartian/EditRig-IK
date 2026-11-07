--!strict
-- Explicitly prepare Roblox IKControl constraint geometry without changing the rig.
local IKConstraintBuilder={}
function IKConstraintBuilder.new(Config)
 local api={}
 local orientations={X=CFrame.identity,Y=CFrame.Angles(0,0,math.pi/2),Z=CFrame.Angles(0,-math.pi/2,0)}
 local function partOf(attachment)
  if not attachment then return nil end
  return attachment:FindFirstAncestorWhichIsA('BasePart')
 end
 local function jointSettings(joint)
  assert(typeof(joint)=='Instance' and joint:IsA('Motor6D') and joint.Parent,'select one parented Motor6D')
  local model=joint:FindFirstAncestorOfClass('Model')
  assert(model and joint.Enabled and joint.Part0 and joint.Part1 and joint.Part0~=joint.Part1 and joint.Part0:IsDescendantOf(model) and joint.Part1:IsDescendantOf(model),'motor must connect distinct parts in the same model')
  assert(joint:GetAttribute('EditRigIK_SchemaVersion')==1,'save joint settings first')
  local config=Config.validate({kind=joint:GetAttribute('EditRigIK_Kind'),axis=joint:GetAttribute('EditRigIK_Axis'),lower=joint:GetAttribute('EditRigIK_LowerDegrees'),upper=joint:GetAttribute('EditRigIK_UpperDegrees'),swing=joint:GetAttribute('EditRigIK_SwingDegrees')})
  return {joint=joint,model=model,p0=joint.Part0,p1=joint.Part1,c0=joint.C0,c1=joint.C1,kind=config.kind,axis=config.axis,lower=config.lower,upper=config.upper,swing=config.swing,name='EditRigIK_'..joint.Name}
 end
 function api.prepare(joint)
  local data=jointSettings(joint)
  local model,p0,p1=data.model,data.p0,data.p1
  for _,item in ipairs(model:GetDescendants()) do
   if item:IsA('Constraint') then
    local a,b=partOf(item.Attachment0),partOf(item.Attachment1)
    assert(not ((a==p0 and b==p1) or (a==p1 and b==p0)),'a constraint already connects these parts')
   end
  end
  local name=data.name
  assert(not p0:FindFirstChild(name..'_0') and not p1:FindFirstChild(name..'_1') and not p1:FindFirstChild(name..'_Hinge') and not p1:FindFirstChild(name..'_Ball'),'generated names already exist')
  return data
 end
 local function same(a,b)
  return a.model==b.model and a.p0==b.p0 and a.p1==b.p1 and a.c0==b.c0 and a.c1==b.c1 and a.kind==b.kind and a.axis==b.axis and a.lower==b.lower and a.upper==b.upper and a.swing==b.swing and a.name==b.name
 end
 function api.apply(prepared)
  assert(type(prepared)=='table','prepared constraint required')
  local current=api.prepare(prepared.joint)
  assert(same(current,prepared),'joint changed; prepare again')
  local a0=Instance.new('Attachment'); local a1=Instance.new('Attachment'); local constraint=if current.kind=='Hinge' then Instance.new('HingeConstraint') else Instance.new('BallSocketConstraint')
  local ok,err=pcall(function()
   a0.Name=current.name..'_0'; a0.CFrame=current.c0*orientations[current.axis]
   a1.Name=current.name..'_1'; a1.CFrame=current.c1*orientations[current.axis]
   constraint.Name=current.name..'_'..current.kind; constraint.Attachment0=a0; constraint.Attachment1=a1
   constraint:SetAttribute('EditRigIK_ConstraintVersion',1)
   local ref=Instance.new('ObjectValue'); ref.Name='EditRigIKJoint'; ref.Value=current.joint; ref.Parent=constraint
   constraint.LimitsEnabled=true
   if constraint:IsA('HingeConstraint') then constraint.LowerAngle=current.lower; constraint.UpperAngle=current.upper
   else constraint.UpperAngle=current.swing; constraint.TwistLimitsEnabled=true; constraint.TwistLowerAngle=current.lower; constraint.TwistUpperAngle=current.upper end
   a0.Parent=current.p0; a1.Parent=current.p1; constraint.Parent=current.p1
  end)
  if not ok then constraint:Destroy(); a0:Destroy(); a1:Destroy(); error(err) end
  return constraint
 end
 function api.prepareRefresh(joint)
  local data=jointSettings(joint)
  local found=nil
  for _,item in ipairs(data.p1:GetChildren()) do
   if item:IsA('Constraint') and item:GetAttribute('EditRigIK_ConstraintVersion')==1 then
    local ref=item:FindFirstChild('EditRigIKJoint')
    if ref and ref:IsA('ObjectValue') and ref.Value==joint then assert(not found,'multiple generated constraints reference this joint'); found=item end
   end
  end
  assert(found,'no supported generated constraint references this joint')
  assert((data.kind=='Hinge' and found:IsA('HingeConstraint')) or (data.kind=='Ball' and found:IsA('BallSocketConstraint')),'constraint type changed; remove or replace it explicitly')
  local a0,a1=found.Attachment0,found.Attachment1
  assert(a0 and a1 and a0:IsA('Attachment') and a1:IsA('Attachment') and a0.Parent==data.p0 and a1.Parent==data.p1,'generated constraint attachments are invalid')
  for _,item in ipairs(data.model:GetDescendants()) do
   if item:IsA('Constraint') and item~=found then
    local x,y=item.Attachment0,item.Attachment1
    assert(x~=a0 and x~=a1 and y~=a0 and y~=a1,'generated attachments are shared by another constraint')
    local p0,p1=partOf(x),partOf(y)
    assert(not ((p0==data.p0 and p1==data.p1) or (p0==data.p1 and p1==data.p0)),'another constraint connects these parts')
   end
  end
  data.constraint=found; data.a0=a0; data.a1=a1
  return data
 end
 function api.refresh(prepared)
  assert(type(prepared)=='table','prepared constraint refresh required')
  local current=api.prepareRefresh(prepared.joint)
  assert(same(current,prepared) and current.constraint==prepared.constraint and current.a0==prepared.a0 and current.a1==prepared.a1,'joint or constraint changed; prepare again')
  local constraint=current.constraint
  current.a0.CFrame=current.c0*orientations[current.axis]
  current.a1.CFrame=current.c1*orientations[current.axis]
  constraint.LimitsEnabled=true
  if constraint:IsA('HingeConstraint') then constraint.LowerAngle=current.lower; constraint.UpperAngle=current.upper
  else constraint.UpperAngle=current.swing; constraint.TwistLimitsEnabled=true; constraint.TwistLowerAngle=current.lower; constraint.TwistUpperAngle=current.upper end
  return constraint
 end
 return api
end
return IKConstraintBuilder
