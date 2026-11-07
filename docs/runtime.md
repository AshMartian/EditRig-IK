# Experimental runtime core

`build/current/EditRigIKRuntime.rbxm` contains a ModuleScript and its `Solver` and `Limits` children. Place the module where your scripts can require it, for example in ReplicatedStorage. It is an experimental mathematical solver, not yet a Motor6D/Bone adapter; it does not discover instances, read the editor's attributes, apply poses, manage Animator, accept a pole, or generate driver scripts. Do not run it on the same joints as an IKControl without first implementing explicit ownership and update ordering.

```lua
local IK = require(game.ReplicatedStorage.EditRigIKRuntime)
local chain = {
    root = {0, 0, 0},
    joints = {
        {
            rest = {0, 0, 0, 1},
            rotation = {0, 0, 0, 1},
            offset = {1, 0, 0},
            limit = {kind = 'Hinge', axis = {0, 0, 1}, lower = 0, upper = math.rad(90)},
        },
        {rest = {0, 0, 0, 1}, rotation = {0, 0, 0, 1}, offset = {1, 0, 0}},
    },
}
local result = IK.solve(chain, {1, 1, 0}, {iterations = 30, tolerance = 0.001})
print(result.converged, result.error, result.endpoint)
-- result.rotations contains one local quaternion per joint; chain is not mutated.
```

Vectors are numeric `{x, y, z}` arrays and quaternions are `{x, y, z, w}`. `root` and target share one coordinate frame, whose orientation is identity. Joint `rest` is a quaternion relative to the previous joint's rotated frame; `rotation` is relative to that rest frame. `offset` is the vector from this joint to the next joint (or final endpoint) in this joint's rotated frame. Limits are in the joint's rest frame, in **radians**. A hinge has `axis`, `lower`, and `upper`; a ball has those fields plus `swing` (cone half-angle). For a model with nonidentity root orientation, an adapter must transform the target and geometry into this frame and translate results back consistently.

The solver uses CCD and applies limits to the initial rotation and after each joint update. It returns `rotations`, `endpoint`, `error`, actual `iterations`, and `converged`. `iterations` must be an integer in 1–1000; tolerance is finite and nonnegative. Invalid axes, ranges, rotations, or zero-length links are rejected. A missed target can be unreachable, constrained, singular or simply not converged; the current diagnostic does not distinguish these cases. There is no pole vector or preferred bend direction, so ambiguous poses can flip. The mathematical tests do not establish compatibility with Roblox's animation update order or real rig transforms.

## Experimental behavior coordinator

`IK.Actor.new(definition, registry)` creates independent behavior instances. Each registry entry is a factory called with a private copy of the behavior's `options`; it returns a table with `step(input, dt)` and optional `destroy(self)`. The coordinator calls enabled behaviors in ascending `priority` (definition order breaks ties) and returns their named results. It does not yet blend, apply, replicate or resolve conflicts between results. The caller owns the update loop and must call `destroy` when finished.

```lua
local registry = {
    counter = function(options)
        local elapsed = 0
        return {
            step = function(input, dt)
                elapsed += dt
                return {elapsed = elapsed, speed = input.speed * options.gain}
            end,
        }
    end,
}
local actor = IK.Actor.new({behaviors = {
    {name = 'example', type = 'counter', priority = 0, options = {gain = 1}},
}}, registry)
local results = actor:step({speed = 4}, 1 / 60)
actor:setEnabled('example', false)
actor:destroy()
```

This is infrastructure for extensible behaviors, not an actor/avatar creation workflow or a procedural animation by itself. Configuration serialization, live tuning, event hooks, lifecycle integration with Roblox instances, behavior blending, generated scripts and built-in animation behaviors remain outstanding.
