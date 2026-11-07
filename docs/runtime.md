# Experimental runtime core

`build/current/EditRigIKRuntime.rbxm` contains a ModuleScript and its `Solver` and `Limits` children. Place the module where your scripts can require it, for example in ReplicatedStorage. It is an experimental mathematical solver, not yet a Motor6D/Bone adapter; the CCD solver does not discover instances, read the editor's attributes, manage Animator, accept a pole, or generate driver scripts. A separate limited single-axis joint adapter is described below. Do not run it on the same joints as an IKControl without first implementing explicit ownership and update ordering.

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

## Named controls and one-shot messages

The coordinator provides `actor:setControl(name, value)`, `actor:clearControl(name)` and `actor:impulse(name, value)`. Values are finite numbers, booleans, or three-number arrays. Controls persist until changed or cleared. Each impulse is a named message delivered once to every enabled behavior on the next successful `actor:step`, in enqueue order. A maximum of 256 may be queued. Each behavior receives an isolated snapshot as its third argument, `{values = ..., impulses = {{name = ..., value = ...}, ...}}`. A successful step drains the messages even if no behavior is enabled. If a behavior throws, messages remain queued; behavior side effects that already happened are not rolled back, so error handlers must avoid blind retries. This API describes routing only: the `JointDrive` behavior interprets scalar impulses as angular velocity; it does not apply Roblox physics forces.

A gameplay input handler can call `actor:setControl('JawOpen', 1)` when a button is pressed and `actor:setControl('JawOpen', 0)` when released. A behavior must explicitly consume that name and implement the joint response. `JointDrive` accepts scalar angular-velocity impulses; other behaviors may define other message formats. These messages are not Roblox physics impulses. An eventual authoring flow will define the mapping and units. Network replication and authorization are not supplied.


## Experimental direct joint control

`IK.JointDrive.new(options)` is a behavior factory for the actor registry. Each binding has a `name`, scalar `control`, optional scalar `impulse`, lower/upper angles in radians enclosing zero, and a positive `frequency` in inverse seconds. A control in `[-1,1]` maps to the corresponding angular limit; out-of-range controls are clamped. An impulse adds angular velocity (radians/second) to a critically damped offset; input and accumulated velocity are clamped to ±100. The combined output is clamped to the joint limits. The behavior returns a map of joint names to angles and never modifies instances itself.

`IK.JointAdapter.new(bindings, {exclusive=true})` captures each `Motor6D.Transform` or `Bone.Transform` and applies angles relative to that captured transform around the configured local `Vector3` axis. Call `adapter:apply(actor:step(input, dt)[1].value)` when this is the first behavior result. It validates all inputs and detects an externally changed transform before writing. `adapter:destroy()` restores transforms it last wrote, leaves externally changed transforms alone, and returns their names. Ownership checks use a tolerance and are not a lock; the caller must ensure no Animator, IKControl, script or other adapter writes the same transforms and must choose appropriate scheduling. There is no automatic arbitration or editor connection yet. Avoid enabling this on Dino Auto's IK-driven legs without first resolving ownership.

In Studio Edit mode, isolated tests created unparented Motor6D and Bone instances, exercised controls, an impulse, application and restoration, and checked that external changes are reported without being overwritten. These checks do not establish behavior in an animated or networked actor, skinned mesh deformation, a packaged module, or a playtest.

## Creating an idle direct-control actor

In the prototype editor, save hinge metadata on each Motor6D or Bone, then select their containing Model and press **Create direct-control actor from selected model**. The builder requires unique configured joint names and ranges that contain zero; it rejects ball limits and unknown metadata versions. It creates an `EditRigIKActor` folder of ObjectValue references and an editable `EditRigIKController` ModuleScript in the model. It does not replace existing objects of those names. The definition is a snapshot: after changing joint metadata, remove or rename the old generated folder and controller before creating a new one. The plugin package and UI have not yet been tested as installed Studio plugins.

Place the separately built `EditRigIKRuntime` ModuleScript in ReplicatedStorage. From a script running on the intended side, after ensuring no Animator, IKControl or other writer owns the configured joints:

```lua
local controller = require(model.EditRigIKController)
local actor = controller.start({exclusive = true})
actor:setControl('Jaw', 0.5)          -- named after the configured joint
actor:impulse('JawImpulse', 1.0)     -- angular velocity, radians/second
-- Call actor:step(dt) from your chosen update loop.
-- Disconnect that loop first when the actor is no longer needed.
local conflicts = controller.stop() -- restores transforms it still owns
```

`exclusive = true` is the caller's assertion, not an automatic lock. The actor does not connect an update event, stop itself on model removal, solve IK, assign network ownership or replicate input. Its controls are local to the environment requiring the controller. An error during `step` can occur after behavior state and impulse queues advance; handle errors and shut down deliberately rather than retrying blindly. The generated definition copies limit values; it does not watch the source joint attributes. Tests used unparented fixture models with source modules, not an animated avatar, a skinned mesh, the installed plugin UI, or the packaged runtime.
