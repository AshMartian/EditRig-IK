local holder=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=holder; a.CFrame=CFrame.new(4,2,1)*CFrame.Angles(0,0,math.rad(30))
local b=Instance.new('Part'); b.Parent=holder
local c=Instance.new('Part'); c.Parent=holder
local j1=Instance.new('Motor6D'); j1.Part0=a; j1.Part1=b; j1.Parent=a
local j2=Instance.new('Motor6D'); j2.Part0=b; j2.Part1=c; j2.C0=CFrame.new(1,0,0); j2.Parent=b
local solver=Solver.new(Limits)
local chain=ChainAdapter.new({j1,j2},Vector3.new(1,0,0),{exclusive=true},solver)
local target=(a.CFrame*CFrame.new(1,1,0)).Position
local result=chain:solve(target,{iterations=40,tolerance=0.001})
assert(result.converged,'Motor6D chain should converge')
local endFrame=a.CFrame*j1.C0*j1.Transform*j1.C1:Inverse()*j2.C0*j2.Transform*j2.C1:Inverse()*CFrame.new(1,0,0)
assert((endFrame.Position-target).Magnitude<0.002,'applied motor transforms must reproduce target')
assert(#chain:destroy()==0 and j1.Transform:FuzzyEq(CFrame.identity,1e-5))
local limited=ChainAdapter.new({j1},Vector3.new(1,0,0),{exclusive=true,limits={{kind='Hinge',axis={0,0,1},lower=0,upper=math.pi/6}}},solver)
local limitedResult=limited:solve((a.CFrame*CFrame.new(0,1,0)).Position,{iterations=6,tolerance=0.001})
assert(not limitedResult.converged and j1.Transform:FuzzyEq(CFrame.Angles(0,0,math.pi/6),1e-5),'hinge limit must constrain the applied pose')
local changed=CFrame.Angles(0,0,0.2); j1.Transform=changed
assert(not pcall(function() limited:solve(target,{iterations=4,tolerance=0.01}) end),'external writer must be detected')
assert(#limited:destroy()==1 and j1.Transform:FuzzyEq(changed,1e-5),'do not overwrite external writer')
j1.Transform=CFrame.identity
local geometry=ChainAdapter.new({j1,j2},Vector3.new(1,0,0),{exclusive=true},solver)
j2.C0=CFrame.new(1.1,0,0)
assert(not pcall(function() geometry:solve(target,{iterations=4,tolerance=0.01}) end),'changed geometry must be rejected')
geometry:destroy(); j2.C0=CFrame.new(1,0,0)
-- Exercise nonidentity C0/C1 rotations and nonzero link offsets.
j1.C0=CFrame.new(.2,.1,0)*CFrame.Angles(0,0,.3)
j1.C1=CFrame.new(-.2,0,0)*CFrame.Angles(0,0,-.25)
j2.C0=CFrame.new(.8,.2,0)*CFrame.Angles(0,0,.2)
j2.C1=CFrame.new(-.15,0,0)*CFrame.Angles(0,0,.1)
local desired=a.CFrame*j1.C0*CFrame.Angles(0,0,.5)*j1.C1:Inverse()*j2.C0*CFrame.Angles(0,0,-.8)*j2.C1:Inverse()*CFrame.new(1,0,0)
local rotatedChain=ChainAdapter.new({j1,j2},Vector3.new(1,0,0),{exclusive=true},solver)
local rotatedResult=rotatedChain:solve(desired.Position,{iterations=100,tolerance=0.002})
local rotatedEnd=a.CFrame*j1.C0*j1.Transform*j1.C1:Inverse()*j2.C0*j2.Transform*j2.C1:Inverse()*CFrame.new(1,0,0)
assert(rotatedResult.converged and (rotatedEnd.Position-desired.Position).Magnitude<0.003,'rotated joint frames must match applied FK')
rotatedChain:destroy()
local root=Instance.new('Bone'); root.Name='Root'; root.Parent=a
local child=Instance.new('Bone'); child.CFrame=CFrame.new(1,0,0); child.Parent=root
local boneChain=ChainAdapter.new({root,child},Vector3.new(1,0,0),{exclusive=true},solver)
local boneResult=boneChain:solve(target,{iterations=40,tolerance=0.001})
assert(boneResult.converged,'Bone chain should converge')
local boneEnd=a.CFrame*root.CFrame*root.Transform*child.CFrame*child.Transform*CFrame.new(1,0,0)
assert((boneEnd.Position-target).Magnitude<0.002,'applied Bone transforms must reproduce target')
assert(#boneChain:destroy()==0)
assert(not pcall(function() ChainAdapter.new({j1,j2},Vector3.new(1,0,0),{},solver) end))
holder:Destroy()
return 'Motor6D and Bone constrained chain adapter passed'
