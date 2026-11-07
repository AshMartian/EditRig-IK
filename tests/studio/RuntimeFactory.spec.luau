local expected={solve=function() return {ok=true} end}
local claims={}
local modules={Solver={new=function() return expected end}, Limits={}, Actor={},JointDrive={},StepTrajectory={},FootstepBehavior={},Ownership={new=function() return claims end},JointAdapter={new=function(_,options) assert(options.ownership==claims); return 'joint' end},ActorRig={},ChainDefinition={new=function(def,options,factory) assert(def=='definition' and options.exclusive and type(factory)=='function'); return 'configured' end},ChainAdapter={new=function(_,_,options,engine) assert(engine==expected and options.ownership==claims,'runtime must share ownership with adapters'); return 'chain' end}}
local runtime=RuntimeFactory(modules,function(item) return item end)
assert(runtime.createIKChain({},Vector3.zero,{exclusive=true})=='chain')
assert(runtime.JointAdapter.new({}, {exclusive=true})=='joint')
assert(runtime.solve({}, {}, {}).ok)
assert(runtime.createConfiguredIKChain('definition',{exclusive=true})=='configured')
return 'Runtime factory passes solver to chain adapter'
