-- Schema 3 snapshot, actual solver, and isolated world/viewport previews for both rig kinds.
local engine=Solver.new(Limits,CircularHinge.v1)
local builder=ChainBuilder.new(Config)
local makeChain=function(def)
 return ChainDefinition.new(def,{exclusive=true},function(joints,point,options)
  return ChainAdapter.new(joints,point,options,engine)
 end,LimitFrame)
end
for _,kind in ipairs({'Motor6D','Bone'}) do
 local model=Instance.new('Model'); model.Name='CircularFixture'..kind
 local base=Instance.new('Part'); base.Name='Base'; base.Anchored=true; base.Parent=model
 local joint,tipParent
 if kind=='Motor6D' then
  local tip=Instance.new('Part'); tip.Name='Tip'; tip.Anchored=true; tip.Parent=model
  joint=Instance.new('Motor6D'); joint.Part0=base; joint.Part1=tip; joint.Parent=base; tipParent=tip
 else
  joint=Instance.new('Bone'); joint.Parent=base; tipParent=joint
 end
 joint.Name='Joint'
 joint:SetAttribute('EditRigIK_SchemaVersion',2); joint:SetAttribute('EditRigIK_Kind','Hinge'); joint:SetAttribute('EditRigIK_Axis','Z')
 joint:SetAttribute('EditRigIK_LowerDegrees',140); joint:SetAttribute('EditRigIK_UpperDegrees',-130)
 joint:SetAttribute('EditRigIK_CircularStartDegrees',140); joint:SetAttribute('EditRigIK_CircularWidthDegrees',90)
 joint:SetAttribute('EditRigIK_SwingDegrees',90); joint:SetAttribute('EditRigIK_Weight',1)
 local endpoint=Instance.new('Attachment'); endpoint.Position=Vector3.xAxis; endpoint.Parent=tipParent
 local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
 local definition=builder.create(model,joint,joint,endpoint,'Circular'); definition.Parent=folder
 assert(definition:GetAttribute('SchemaVersion')==3,'circular snapshot must use schema 3')
 local ref=definition.Joints.Joint001
 assert(ref:GetAttribute('CircularStartDegrees')==140 and ref:GetAttribute('CircularWidthDegrees')==90 and ref:GetAttribute('LowerDegrees')==nil,'circular snapshot must retain wrapping semantics')
 local observations=0
 local guarded=ChainBuilder.new(Config,function(active)
  observations+=1
  assert(active:GetAttribute('SchemaVersion')==0,'snapshot must be unpublished while fields change')
  assert(not pcall(makeChain,active),'runtime must reject a partially refreshed snapshot')
 end)
 guarded.refreshLimits(definition)
 assert(observations>0 and definition:GetAttribute('SchemaVersion')==3,'schema 3 refresh must publish after all writes')
 local interrupted=ChainBuilder.new(Config,function() error('injected refresh interruption') end)
 local before=ref:GetAttributes()
 assert(not pcall(interrupted.refreshLimits,definition),'interrupted refresh must report failure')
 assert(definition:GetAttribute('SchemaVersion')==3,'interrupted refresh must restore the prior schema')
 for key,value in pairs(before) do assert(ref:GetAttribute(key)==value,'interrupted refresh must restore '..key) end
 local savedW=ref:GetAttribute('FrameW'); ref:SetAttribute('FrameW',0)
 assert(not pcall(builder.refreshLimits,definition),'zero quaternion must fail before refresh')
 assert(definition:GetAttribute('SchemaVersion')==3 and ref:GetAttribute('FrameW')==0,'invalid input must not change the snapshot')
 ref:SetAttribute('FrameW',savedW)
 -- Exercise the schema 1 to 3 publication boundary as well.
 joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_LowerDegrees',-90); joint:SetAttribute('EditRigIK_UpperDegrees',90)
 local legacy=builder.create(model,joint,joint,endpoint,'Legacy'); legacy.Parent=folder
 joint:SetAttribute('EditRigIK_SchemaVersion',2); joint:SetAttribute('EditRigIK_LowerDegrees',140); joint:SetAttribute('EditRigIK_UpperDegrees',-130)
 observations=0; guarded.refreshLimits(legacy)
 assert(observations>0 and legacy:GetAttribute('SchemaVersion')==3,'schema 1 upgrade must publish only when complete')
 legacy:Destroy()
 local parent=Instance.new('Folder')
 local ghost=WorldGhostSession.new(definition,parent,{createChain=makeChain})
 local solved=ghost:solveTarget(Vector3.new(-1,0,0))
 assert(solved.error<.05,kind..' ghost should solve into the wrapping interval')
 assert(joint.Transform:FuzzyEq(CFrame.identity,1e-5),kind..' ghost must leave the source pose unchanged')
 ghost:reset(); ghost:destroy(); assert(#parent:GetChildren()==0,'ghost must be removed')
 local viewport=Instance.new('ViewportFrame')
 local preview=PreviewSession.new(definition,viewport,{createChain=makeChain})
 local previewResult=preview:solveOffset(Vector3.new(-2,0,0))
 assert(previewResult.error<.05,kind..' viewport should solve into the wrapping interval')
 assert(joint.Transform:FuzzyEq(CFrame.identity,1e-5),kind..' viewport must leave the source pose unchanged')
 preview:destroy(); assert(#viewport:GetChildren()==0,'viewport must be cleaned up')
 viewport:Destroy(); parent:Destroy(); model:Destroy()
end
return 'Circular chain snapshots and isolated previews work for Motor6D and Bone'
