local model=Instance.new('Model')
local a=Instance.new('Part'); a.Parent=model
local b=Instance.new('Part'); b.Parent=model
local motor=Instance.new('Motor6D'); motor.Part0=a; motor.Part1=b; motor.Parent=a
local bone=Instance.new('Bone'); bone.Parent=a
local ownership=Ownership.new()
local options={exclusive=true,ownership=ownership}
local drive=JointAdapter.new({{name='motor',joint=motor,axis=Vector3.zAxis}},options)
assert(not pcall(function() ChainAdapter.new({motor},Vector3.xAxis,options,Solver.new(Limits)) end),'chain must reject a joint owned by a direct drive')
local other=JointAdapter.new({{name='bone',joint=bone,axis=Vector3.zAxis}},options)
assert(not pcall(function() JointAdapter.new({{name='bone',joint=bone,axis=Vector3.zAxis}},options) end),'duplicate drive must be rejected')
drive:destroy()
local chain=ChainAdapter.new({motor},Vector3.xAxis,options,Solver.new(Limits))
assert(not pcall(function() JointAdapter.new({{name='motor',joint=motor,axis=Vector3.zAxis}},options) end),'drive must reject a joint owned by a chain')
chain:destroy(); chain:destroy()
local replacement=JointAdapter.new({{name='motor',joint=motor,axis=Vector3.zAxis}},options)
replacement:apply({motor=0.2})
motor.Transform=CFrame.Angles(0,0,0.4)
assert(#replacement:destroy()==1,'external writes must still be reported')
local afterConflict=JointAdapter.new({{name='motor',joint=motor,axis=Vector3.zAxis}},options)
afterConflict:destroy(); other:destroy(); model:Destroy()
return 'Shared ownership rejects overlaps and releases joints'
