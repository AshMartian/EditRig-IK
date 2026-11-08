local model=Instance.new('Model')
local base=Instance.new('Part'); base.Parent=model
local tip=Instance.new('Part'); tip.Parent=model
local joint=Instance.new('Motor6D'); joint.Part0=base; joint.Part1=tip; joint.Parent=base
joint:SetAttribute('EditRigIK_SchemaVersion',1); joint:SetAttribute('EditRigIK_Kind','Ball'); joint:SetAttribute('EditRigIK_Axis','X')
joint:SetAttribute('EditRigIK_LowerDegrees',-180); joint:SetAttribute('EditRigIK_UpperDegrees',180); joint:SetAttribute('EditRigIK_SwingDegrees',180)
local endpoint=Instance.new('Attachment'); endpoint.CFrame=CFrame.new(1,0,0)*CFrame.Angles(.2,.3,.4); endpoint.Parent=tip
local folder=Instance.new('Folder'); folder.Name='EditRigIKChains'; folder.Parent=model
local definition=ChainBuilder.new(Config).create(model,joint,joint,endpoint,'Foot'); definition.Parent=folder
local capturedCreation,capturedSolve
local chain=ChainDefinition.new(definition,{exclusive=true},function(_,_,options)
 capturedCreation=options
 return {solve=function(_,_,settings) capturedSolve=settings; return {} end,destroy=function() return {} end}
end)
assert(capturedCreation.endpointOrientation and capturedCreation.endpointOrientation:FuzzyEq(endpoint.CFrame.Rotation,1e-5),'configured chain must preserve the attachment orientation')
local target=CFrame.Angles(.1,.2,.3)
chain:solve(Vector3.zero,{targetOrientation=target,orientationTolerance=.01})
assert(capturedSolve.targetOrientation==target and capturedSolve.orientationTolerance==.01,'orientation options must reach the solver')
endpoint.CFrame=endpoint.CFrame*CFrame.Angles(0,.3,0)
assert(not pcall(function() chain:solve(Vector3.zero) end),'endpoint rotation changes require rebuilding the chain')
chain:destroy(); model:Destroy()
return 'Configured chain preserves and validates its endpoint orientation'
