local expected={solve=function() return {ok=true} end}
local modules={Solver={new=function() return expected end}, Limits={}, Actor={},JointDrive={},JointAdapter={},ActorRig={},ChainDefinition={new=function(def,options,factory) assert(def=='definition' and options.exclusive and type(factory)=='function'); return 'configured' end},ChainAdapter={new=function(_,_,_,engine) assert(engine==expected,'runtime must pass its solver'); return 'chain' end}}
local runtime=RuntimeFactory(modules,function(item) return item end)
assert(runtime.createIKChain({},Vector3.zero,{exclusive=true})=='chain')
assert(runtime.solve({}, {}, {}).ok)
assert(runtime.createConfiguredIKChain('definition',{exclusive=true})=='configured')
return 'Runtime factory passes solver to chain adapter'
