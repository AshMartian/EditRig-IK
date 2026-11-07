local actor=Actor.new({behaviors={{name='ball',type='ball',options={joints={{name='Shoulder',control='Aim',impulse='Push',axis={0,1,0},lower=-math.pi/4,upper=math.pi/4,swing=math.pi/3,frequency=4}}}}}},{ball=function(options) return BallDrive.new(options,Limits) end})
local context=Instance.new('InputContext'); local action=Instance.new('InputAction'); action.Type=Enum.InputActionType.Bool; action.Parent=context
local key=Instance.new('InputBinding'); key.Type=Enum.InputBindingType.Scriptable; key.Parent=action
local inputs=InputBindings.new(actor); inputs:bindImpulse(action,'Push',{1,0,0})
key:Fire(true); task.wait()
local q=actor:step({},.1)[1].value.Shoulder
assert(q[1]>0,'button impulse should reach ball behavior')
local model=Instance.new('Model'); local part=Instance.new('Part'); part.Parent=model
local motor=Instance.new('Motor6D'); motor.Parent=part; local bone=Instance.new('Bone'); bone.Parent=part
local rotation=CFrame.new(0,0,0,q[1],q[2],q[3],q[4])
motor.Transform=rotation; bone.Transform=rotation
assert(motor.Transform:FuzzyEq(rotation,1e-5) and bone.Transform:FuzzyEq(rotation,1e-5),'quaternion can be applied to both joint types')
inputs:destroy(); actor:destroy(); context:Destroy(); model:Destroy()
return 'Ball behavior receives scriptable input and produces Motor6D/Bone rotations'
