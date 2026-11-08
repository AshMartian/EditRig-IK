local expected={solve=function() return {ok=true} end}
local claims={}
local frameModule={}
local limitsModule={}
local circularV1={}
local circularModule={v1=circularV1}
local modules={Solver={new=function(limits,circular) assert(limits==limitsModule and circular==circularV1,'runtime must inject circular hinge into solver'); return expected end}, Limits=limitsModule, CircularHinge=circularModule, LimitFrame=frameModule, Actor={},JointDrive={},StepTrajectory={},FootstepBehavior={},FootstepChain={new=function(options,components) assert(options.exclusive and type(components.createChain)=='function'); return 'footstep' end},Ownership={new=function() return claims end},JointAdapter={new=function(_,options) assert(options.ownership==claims); return 'joint' end},ActorRig={},ChainDefinition={new=function(def,options,factory,frame) assert(def=='definition' and options.exclusive and type(factory)=='function' and frame==frameModule,'configured chains must receive the limit-frame module'); return 'configured' end},ChainAdapter={new=function(_,_,options,engine) assert(engine==expected and options.ownership==claims,'runtime must share ownership with adapters'); return 'chain' end}}
local runtime=RuntimeFactory(modules,function(item) return item end)
assert(runtime.createIKChain({},Vector3.zero,{exclusive=true})=='chain')
assert(runtime.JointAdapter.new({}, {exclusive=true})=='joint')
assert(runtime.solve({}, {}, {}).ok)
assert(runtime.createConfiguredIKChain('definition',{exclusive=true})=='configured')
assert(runtime.createFootstepChain('definition',{exclusive=true})=='footstep')
return 'Runtime factory passes solver to chain adapter'
