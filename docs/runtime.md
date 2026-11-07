# Experimental runtime core

`build/current/EditRigIKRuntime.rbxm` contains a ModuleScript and its `Solver` and `Limits` children. Place the module where your scripts can require it, for example in ReplicatedStorage. Its experimental CCD solver supports an explicit Motor6D/Bone chain adapter; it does not discover chains, read the editor's attributes, manage Animator, accept a pole, or generate IK driver scripts. A separate limited single-axis joint adapter is described below. Do not run it on the same joints as an IKControl without first implementing explicit ownership and update ordering.

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

The solver uses CCD and applies limits to the initial rotation and after each joint update. It returns `rotations`, `endpoint`, `error`, actual `iterations`, and `converged`. `iterations` must be an integer in 1–1000; tolerance is finite and nonnegative. Optional `maxStep` limits each joint's correction per iteration in radians, greater than zero and at most pi; it defaults to pi. This limits a solver iteration, not the total change per frame or a time-based smoothing speed. Invalid axes, ranges, rotations, or zero-length links are rejected. A missed target can be unreachable, constrained, singular or simply not converged; the current diagnostic does not distinguish these cases. There is no pole vector or preferred bend direction, so ambiguous poses can flip. Isolated Studio fixtures have exercised both chain types, but these tests do not establish compatibility with Animator, real skinned meshes, or a live rig.

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

The driver commits its internal joint states only after all of its inputs for a step validate. A rejected control or impulse therefore does not partially advance earlier joints. This guarantee applies to the driver itself: the actor coordinator cannot roll back other behaviors that already ran, or adapter writes that fail later.

`IK.JointAdapter.new(bindings, {exclusive=true})` captures each `Motor6D.Transform` or `Bone.Transform` and applies angles relative to that captured transform around the configured local `Vector3` axis. Call `adapter:apply(actor:step(input, dt)[1].value)` when this is the first behavior result. It validates all inputs and detects an externally changed transform before writing. `adapter:destroy()` restores transforms it last wrote, leaves externally changed transforms alone, and returns their names. Ownership checks use a tolerance and are not a lock; the caller must ensure no Animator, IKControl, script or other adapter writes the same transforms and must choose appropriate scheduling. There is no automatic arbitration or editor connection yet. Avoid enabling this on Dino Auto's IK-driven legs without first resolving ownership.

In Studio Edit mode, isolated tests created unparented Motor6D and Bone instances, exercised controls, an impulse, application and restoration, and checked that external changes are reported without being overwritten. These checks do not establish behavior in an animated or networked actor, skinned mesh deformation, a packaged module, or a playtest.

## Creating an idle direct-control actor

In the prototype editor, save hinge metadata on each Motor6D or Bone, then select their containing Model and press **Create direct-control actor from selected model**. The joint fields include control name, impulse name and impulse damping frequency (0.01–100 inverse seconds); blank names default to the joint name and joint name plus `Impulse`. Multiple joints may share a control or impulse name. These settings are used by the direct-control actor, not by the IK chain solver. The builder requires unique configured joint names and ranges that contain zero; it rejects ball limits and unknown metadata versions. It creates an `EditRigIKActor` folder of ObjectValue references and an editable `EditRigIKController` ModuleScript in the model. It does not replace existing objects of those names. The definition is a snapshot: after changing joint metadata, remove or rename the old generated folder before creating a new one; a compatible controller can be reused. The installed plugin toolbar and panel opening were confirmed; its individual controls have not yet been tested interactively.

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

`exclusive = true` is the caller's assertion about external writers. A runtime module instance also rejects overlapping joint claims between its own actors, IK chains and direct adapters, releasing claims on `destroy`. This registry does not coordinate separate copies of the runtime, separate client/server environments, Animator, IKControl or other scripts. Call `destroy` when finished; discarding a live controller is not a supported cleanup strategy. The actor does not connect an update event, stop itself on model removal, solve IK, assign network ownership or replicate input. Its controls are local to the environment requiring the controller. An error during `step` can occur after behavior state and impulse queues advance; handle errors and shut down deliberately rather than retrying blindly. The generated definition copies limit values; it does not watch the source joint attributes. Tests used unparented fixture models with source modules, not an animated avatar, a skinned mesh, the installed plugin UI, or the packaged runtime.


## Experimental explicit IK chain

`IK.createIKChain(joints, endpointLocal, {exclusive = true, limits = limits})` creates a manual, position-only chain. `joints` must be an ordered, nonempty array of connected Motor6Ds or directly parented Bones, with no mixed types. For a Motor6D chain, `endpointLocal` is a Vector3 in the last joint's Part1 space; for Bones it is in the last Bone's transformed local space. The adapter derives link offsets and rest orientations, converts a world-space target into the chain root frame, runs CCD, and applies the returned rotations to `Transform`. `limits[i]`, when supplied, follows the numerical solver's hinge/ball format and uses radians and the joint's local rest frame.

```lua
local chain = IK.createIKChain({hipMotor, kneeMotor}, Vector3.new(0, -1, 0), {
    exclusive = true,
    limits = {
        {kind = 'Ball', axis = {0, 1, 0}, swing = math.rad(70), lower = math.rad(-30), upper = math.rad(30)},
        {kind = 'Hinge', axis = {1, 0, 0}, lower = 0, upper = math.rad(100)},
    },
})
local result = chain:solve(target.WorldPosition, {iterations = 30, tolerance = 0.01})
print(result.converged, result.error, result.endpointWorld)
local conflicts = chain:destroy()
```

The runtime rejects overlapping claims from its own actors and chains, but this is not a lock against external writers. Existing Animator, IKControl, and other writers must be managed by the caller. The adapter rejects translated joint `Transform`s, zero-length offsets, disconnected chains, changed rest geometry, and externally changed transforms. It applies the best result even when `converged` is false, so callers must inspect diagnostics. Restore reports indices of joints overwritten by someone else and leaves those transforms alone. It does not connect an update loop or manage replication. Animator timing, real physics, skinned mesh deformation, live Dino Auto, editor integration, poles and preferred bending remain unverified or unimplemented. The joint limit axes in the example are illustrative only.


## Authoring and opening an IK chain

In the editor, save hinge or ball settings on every joint in the intended chain. Select the root joint and click **Set root joint**, select the end joint and click **Set end joint**, then select a regular Attachment directly under the final Motor6D's Part1 or final Bone and click **Set endpoint attachment**. Enter a chain name, CCD iteration limit, tolerance in studs, and maximum correction per iteration in degrees, then click **Create idle IK chain definition**. The default correction is 180 degrees; old saved chains use that default. The builder requires a single directed path and rejects ambiguous, cyclic, disconnected, mixed-type, or unconfigured chains. It creates a snapshot under the containing model's `EditRigIKChains` and an idle controller if one does not already exist. It does not overwrite an existing chain.

With the runtime installed in ReplicatedStorage, and after resolving all competing writers:

```lua
local controller = require(model.EditRigIKController)
local leg = controller.openChain('Leg', {exclusive = true})
local result = leg:solve(target.WorldPosition) -- uses authored iteration/tolerance
-- Override any setting, e.g. {iterations = 40, maxStep = math.rad(20)}.
print(result.converged, result.error)
-- Stop your update loop before restoring the owned transforms.
local conflicts = leg:destroy()
```

Opening does not start an update loop or disable an IKControl. Same-runtime overlap is rejected, but the creator must manage external writers, scheduling and networking. Saved limits are snapshots, so recreate the definition after editing a joint. Changing or reparenting the endpoint after opening requires closing and reopening the chain. The helper supports only explicitly authored limits and position targets; pole/bend preference, visual previews, AnimationConstraint rigs and external conflict resolution are not implemented. The installed toolbar and panel opening were confirmed, but the authoring controls and packaged runtime have not been tested interactively. Source-level Studio tests used isolated Motor6D and Bone fixtures, including ambiguous path and endpoint-change checks, not a live dinosaur or skinned mesh.
