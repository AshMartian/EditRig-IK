--!strict
-- Experimental, engine-independent core. See docs/runtime.md for conventions.
local Solver = require(script.Solver)
local Limits = require(script.Limits)
local Runtime = {}
Runtime.Actor = require(script.Actor)
Runtime.JointDrive = require(script.JointDrive)
Runtime.JointAdapter = require(script.JointAdapter)
local engine = Solver.new(Limits)
function Runtime.solve(chain, target, options)
    return engine.solve(chain, target, options)
end
return Runtime
