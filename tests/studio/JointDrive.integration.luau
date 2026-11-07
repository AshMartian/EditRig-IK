-- Executed in Studio; all test instances are unparented.
local joint=Instance.new('Motor6D')
local bone=Instance.new('Bone')
local actor=Actor.new({behaviors={{name='driver',type='joint',options={joints={
 {name='jaw',control='open',impulse='kick',lower=-0.5,upper=1,frequency=4},
 {name='tail',control='swing',lower=-1,upper=1,frequency=4},
}}}}}, {joint=JointDrive.new})
local adapter=JointAdapter.new({{name='jaw',joint=joint,axis=Vector3.yAxis},{name='tail',joint=bone,axis=Vector3.zAxis}}, {exclusive=true})
actor:setControl('open',0.5)
actor:setControl('swing',-0.5)
local outputs=actor:step({},0.1)
adapter:apply(outputs[1].value)
assert(joint.Transform:FuzzyEq(CFrame.Angles(0,0.5,0),1e-5))
assert(bone.Transform:FuzzyEq(CFrame.Angles(0,0,-0.5),1e-5))
actor:impulse('kick',1)
outputs=actor:step({},0.1)
assert(outputs[1].value.jaw>0.5)
adapter:apply(outputs[1].value)
assert(#adapter:destroy()==0)
assert(joint.Transform:FuzzyEq(CFrame.identity,1e-5))
assert(bone.Transform:FuzzyEq(CFrame.identity,1e-5))
actor:destroy(); joint:Destroy(); bone:Destroy()
return 'Actor controls, impulses and Motor6D/Bone adapter integration passed'
