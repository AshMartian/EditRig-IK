-- Executed in Studio with JointAdapter supplied by the harness; instances stay unparented.
local motor=Instance.new('Motor6D')
local bone=Instance.new('Bone')
motor.Transform=CFrame.Angles(0,0.2,0)
bone.Transform=CFrame.Angles(0,0,0.1)
local beforeMotor,beforeBone=motor.Transform,bone.Transform
local adapter=JointAdapter.new({{name='jaw',joint=motor,axis=Vector3.yAxis}, {name='tail',joint=bone,axis=Vector3.zAxis}}, {exclusive=true})
adapter:apply({jaw=0.5,tail=-0.25})
local expectedMotor=beforeMotor*CFrame.fromAxisAngle(Vector3.yAxis,0.5)
local expectedBone=beforeBone*CFrame.fromAxisAngle(Vector3.zAxis,-0.25)
assert(motor.Transform:FuzzyEq(expectedMotor,1e-5))
assert(bone.Transform:FuzzyEq(expectedBone,1e-5))
local external=CFrame.Angles(0.4,0,0)
bone.Transform=external
local motorBeforeFailedApply=motor.Transform
assert(not pcall(function() adapter:apply({jaw=0.1,tail=0.1}) end), 'external writer must abort apply')
assert(motor.Transform:FuzzyEq(motorBeforeFailedApply,1e-5), 'failed validation must not partially apply')
local conflicts=adapter:destroy()
assert(motor.Transform:FuzzyEq(beforeMotor,1e-5), 'owned transform must restore')
assert(bone.Transform:FuzzyEq(external,1e-5), 'external changes must not be overwritten')
assert(#conflicts==1 and conflicts[1]=='tail', 'external writer must be reported')
assert(not pcall(function() JointAdapter.new({{name='x',joint=motor,axis=Vector3.xAxis}}, {}) end))
motor:Destroy(); bone:Destroy()
return 'Motor6D and Bone adapter test passed'
