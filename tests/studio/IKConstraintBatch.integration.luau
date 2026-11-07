local model=Instance.new('Model'); local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model; local c=Instance.new('Part'); c.Parent=model
local function motor(name,p0,p1,kind)
 local m=Instance.new('Motor6D'); m.Name=name; m.Part0=p0; m.Part1=p1; m.Parent=p0
 m:SetAttribute('EditRigIK_SchemaVersion',1); m:SetAttribute('EditRigIK_Kind',kind); m:SetAttribute('EditRigIK_Axis','Z')
 m:SetAttribute('EditRigIK_LowerDegrees',-10); m:SetAttribute('EditRigIK_UpperDegrees',35); m:SetAttribute('EditRigIK_SwingDegrees',25)
 return m
end
local j1=motor('Hip',a,b,'Hinge'); local j2=motor('Knee',b,c,'Ball')
local builder=IKConstraintBuilder.new(Config)
assert(not pcall(builder.prepareBatch,{j1,j1}),'duplicate joints must be rejected')
local prepared=builder.prepareBatch({j1,j2})
assert(#a:GetChildren()==1 and #b:GetChildren()==1 and #c:GetChildren()==0,'preparation must not change the rig')
j2:SetAttribute('EditRigIK_UpperDegrees',40)
assert(not pcall(builder.applyBatch,prepared),'stale settings on any joint must reject the entire batch')
assert(#a:GetChildren()==1 and #b:GetChildren()==1 and #c:GetChildren()==0,'stale batch must not create anything')
local originalApply=builder.apply; local calls=0
builder.apply=function(entry) calls+=1; if calls==2 then error('injected second creation failure') end; return originalApply(entry) end
assert(not pcall(builder.applyBatch,builder.prepareBatch({j1,j2})),'failed creation must report the error')
builder.apply=originalApply
assert(#a:GetChildren()==1 and #b:GetChildren()==1 and #c:GetChildren()==0,'failed batch must remove previously created objects')
local constraints=builder.applyBatch(builder.prepareBatch({j1,j2}))
assert(#constraints==2 and constraints[1]:IsA('HingeConstraint') and constraints[2]:IsA('BallSocketConstraint'),'batch must create both configured types')
assert(constraints[1].UpperAngle==35 and constraints[2].TwistUpperAngle==40,'each joint must retain its own limits')
for _,item in ipairs(constraints) do item.Attachment0:Destroy(); item.Attachment1:Destroy(); item:Destroy() end
local j3=motor('Duplicate',b,a,'Hinge')
assert(not pcall(builder.prepareBatch,{j1,j3}),'motors connecting the same parts must be rejected')
j3:Destroy()
local collision=motor('Hip',c,b,'Hinge')
assert(not pcall(builder.prepareBatch,{j1,collision}),'generated attachment names must not collide on a shared part')
collision:Destroy()
j2:SetAttribute('EditRigIK_SchemaVersion',nil)
assert(not pcall(builder.prepareBatch,{j1,j2}),'missing metadata must reject the entire batch')
assert(#a:GetChildren()==1 and #b:GetChildren()==1 and #c:GetChildren()==0,'invalid selection must not mutate the rig')
model:Destroy()
return 'Constraint batches validate all joints and create mixed limits'
