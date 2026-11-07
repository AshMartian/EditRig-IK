local model=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=model; a.CFrame=CFrame.new(4,2,1)*CFrame.Angles(.2,.3,.4)
local b=Instance.new('Part'); b.Parent=model
local c=Instance.new('Part'); c.Parent=model
local j1=Instance.new('Motor6D'); j1.Part0=a; j1.Part1=b; j1.Parent=a
local j2=Instance.new('Motor6D'); j2.Part0=b; j2.Part1=c; j2.Parent=b
local bone=Instance.new('Bone'); bone.Parent=a
local child=Instance.new('Bone'); child.Parent=bone
local solver=Solver.new(Limits)
local target=a.CFrame:PointToWorldSpace(Vector3.yAxis)
for _,joints in ipairs({{j1,j2},{bone,child}}) do
 local chain=ChainAdapter.new(joints,Vector3.xAxis,{exclusive=true},solver)
 local result=chain:solve(target,{iterations=10,tolerance=1e-6})
 assert(result.converged and (result.endpointWorld-target).Magnitude<1e-5,'coincident pivots must reach the target')
 local actual=if joints[1]:IsA('Motor6D') then a.CFrame*j1.C0*j1.Transform*j1.C1:Inverse()*j2.C0*j2.Transform*j2.C1:Inverse()*CFrame.new(Vector3.xAxis) else a.CFrame*bone.CFrame*bone.Transform*child.CFrame*child.Transform*CFrame.new(Vector3.xAxis)
 assert((actual.Position-target).Magnitude<1e-5,'applied joint transforms must match solver endpoint')
 assert(#chain:destroy()==0,'fixture transforms must restore cleanly')
end
model:Destroy()
return 'Motor6D and Bone coincident pivots reach target and match applied poses'
