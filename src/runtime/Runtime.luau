--!strict
-- Experimental, engine-independent core. See docs/runtime.md for conventions.
local Solver = require(script.Solver)
local Limits = require(script.Limits)
local engine = Solver.new(Limits)
local Runtime = {}
Runtime.Actor = require(script.Actor)
Runtime.JointDrive = require(script.JointDrive)
local JointAdapter = require(script.JointAdapter)
local ownership = require(script.Ownership).new()
local function ownedOptions(options)
    assert(type(options)=='table','options are required')
    local copy=table.clone(options)
    copy.ownership=ownership
    return copy
end
Runtime.JointAdapter = {new=function(bindings, options)
    return JointAdapter.new(bindings, ownedOptions(options))
end}
local ChainAdapter = require(script.ChainAdapter)
function Runtime.createIKChain(joints, endpointLocal, options)
    return ChainAdapter.new(joints, endpointLocal, ownedOptions(options), engine)
end
local ChainDefinition = require(script.ChainDefinition)
function Runtime.createConfiguredIKChain(definition, options)
    return ChainDefinition.new(definition, options, Runtime.createIKChain)
end
local ActorRig = require(script.ActorRig)
function Runtime.createActor(definition, options)
    assert(type(options)=='table' and options.exclusive==true, 'explicit exclusive ownership is required')
    return ActorRig.new(definition, {Actor=Runtime.Actor, JointDrive=Runtime.JointDrive, JointAdapter=Runtime.JointAdapter})
end
function Runtime.solve(chain, target, options)
    return engine.solve(chain, target, options)
end
return Runtime
