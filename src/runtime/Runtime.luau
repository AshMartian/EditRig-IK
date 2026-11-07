--!strict
-- Experimental, engine-independent core. See docs/runtime.md for conventions.
local Solver = require(script.Solver)
local Limits = require(script.Limits)
local Runtime = {}
Runtime.Actor = require(script.Actor)
Runtime.JointDrive = require(script.JointDrive)
Runtime.JointAdapter = require(script.JointAdapter)
local ActorRig = require(script.ActorRig)
function Runtime.createActor(definition, options)
    assert(type(options)=='table' and options.exclusive==true, 'explicit exclusive ownership is required')
    return ActorRig.new(definition, {Actor=Runtime.Actor, JointDrive=Runtime.JointDrive, JointAdapter=Runtime.JointAdapter})
end
local engine = Solver.new(Limits)
function Runtime.solve(chain, target, options)
    return engine.solve(chain, target, options)
end
return Runtime
