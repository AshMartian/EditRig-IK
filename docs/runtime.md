# Experimental runtime core

`build/current/EditRigIKRuntime.rbxm` contains the runtime ModuleScript and its components. The prototype editor's **Install runtime in ReplicatedStorage** button prepares a copy of the runtime bundled with that plugin and inserts it with undo waypoints. It refuses to overwrite any existing `EditRigIKRuntime`; inspect and deliberately rename or remove an old copy before installing an update. Installation does not start a controller. Alternatively, place the standalone package where scripts can require it. A source-level Studio fixture cloned and required the runtime in a detached container; the installed plugin button and resulting package have not yet been verified interactively. Its experimental CCD solver supports explicit and authored Motor6D/Bone chain adapters. A separate limited single-axis joint adapter is described below. Do not run it on the same joints as an IKControl without first implementing explicit ownership and update ordering.

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

The solver uses CCD and applies limits to the initial rotation and after each joint update. It returns `rotations`, `endpoint`, `error`, actual `iterations`, and `converged`. `iterations` must be an integer in 1–1000; tolerance is finite and nonnegative. Optional `maxStep` limits each joint's correction per iteration in radians, greater than zero and at most pi; it defaults to pi. This limits a solver iteration, not the total change per frame or a time-based smoothing speed. Optional `gain` scales each CCD, pole-seed, and pole-adjustment angle before that cap; it must be greater than 0 and at most 1, and defaults to 1. The editor saves it per chain as `CorrectionGain`; older definitions default to 1. Lower values can soften individual iterations but many iterations can still produce a large pose change in one update, so it is not a time-based speed limit. An optional numeric `pole` point uses the same frame as the target and requests a bend direction. For a nearly straight chain with a closer collinear target, a small limit-respecting root rotation seeds a bend toward the pole before CCD. After CCD, the solver rotates the root around the root-to-end axis to steer the first bend toward the pole, bounded by `maxStep` and root limits. It rejects a correction that worsens endpoint error. The seed and pole adjustment are additional corrections, so `maxStep` is not a cap on the entire solve. `poleStatus` reports `none`, `applied`, `aligned`, `blocked`, or `degenerate`; `applied` does not promise full alignment. A pole on the root-to-end axis or constrained joint can remain degenerate, and this heuristic does not guarantee stable bends or remove every flip. Individual zero-length links are allowed for coincident pivots, but a chain with no nonzero links is rejected. Invalid axes, ranges and rotations are rejected. A missed target can be unreachable, constrained, singular or simply not converged; the current diagnostic does not distinguish these cases. Isolated Studio fixtures have exercised both chain types, but these tests do not establish compatibility with Animator, real skinned meshes, or a live rig.

## Smooth target motion for an existing IKControl

`IK.createTargetStepper(target, options)` drives an existing anchored BasePart or Attachment in world space. It can move the target of a built-in IKControl without taking over its joints. It does not find ground, schedule alternating feet, or disable the existing gait script; the caller must ensure that script and other writers are not moving the same target. Roblox's [IKControl documentation](https://create.roblox.com/docs/reference/engine/classes/IKControl) describes the supported target and pole relationships.

```lua
local IK = require(game.ReplicatedStorage.EditRigIKRuntime)
local mover = IK.createTargetStepper(targetPartOrAttachment, {
    exclusive = true, up = Vector3.yAxis, height = 1, duration = 0.3,
})
mover:requestStep(worldFootGoal)
-- Call once per update from your chosen loop:
local state = mover:step(dt)
-- state.position, state.moving, state.progress
-- On shutdown, disconnect the update loop first:
mover:destroy()
```

A new or retargeted swing starts from the target's current world position. `step(0)` is useful for checking the starting position; `step(dt)` moves it along the smooth trajectory. Part targets must remain anchored; attachments can have a moving parent. The driver detects local position writes or reparenting between calls and refuses to overwrite them. Runtime ownership prevents two drivers from the same runtime claiming a target, but cannot prevent other scripts or another runtime from writing between checks. Destroy releases the claim and leaves the target where it is. Orientation is not driven, so Transform-type IKControls retain their existing orientation behavior. This has only been tested on isolated Studio instances, not in live play or on Dino Auto.

## Dino Auto smooth-gait experiment

[The editable example](../examples/DinoSmoothGait.luau) alternates two anchored targets named like Dino Auto's existing targets. It raycasts below each ray part, steps only when the ground point is far enough from that foot's last planted position, and holds the opposite foot while swinging. It starts with each target's current position, avoiding the old world-origin initialization. The plugin can insert it as an editable, disabled example: select a compatible model and choose **Add disabled Dino smooth-gait example**. It inserts `EditRigIKSmoothGaitExample` with a child `DinoSmoothGait` ModuleScript and refuses to overwrite an existing example. The button has not yet been tested interactively. The example is not started automatically.

For an isolated live comparison, install the updated runtime, add the disabled example using the button, and review its settings. The inserted script requires its child ModuleScript and explicitly steps the gait. The following shows the same pattern for a custom controller:

```lua
local RunService = game:GetService('RunService')
local IK = require(game.ReplicatedStorage.EditRigIKRuntime)
local SmoothGait = require(script.DinoSmoothGait) -- adjust to the ModuleScript location
local gait = SmoothGait.new(script.Parent, IK, {
    distance = 2, forward = 2, height = 1, duration = 0.3,
})
local update = RunService.Heartbeat:Connect(function(dt)
    gait:step(dt)
end)
-- To stop the experiment, disconnect first, then release target ownership:
-- update:Disconnect(); gait:destroy()
```

Disable the old model script before starting this experiment: both would otherwise write the targets. The bundled runner checks a direct child named `Script` and refuses to start if that script is enabled; it cannot discover every possible writer. Stop Play to fully end the comparison and release its runtime state. That script also controls movement, orientation, pole assignment, and helper visibility, so disabling it affects those behaviors; this example deliberately does not replace them. Set poles and character movement separately if needed. After stopping the example, re-enable the original script to restore the original gait. Avoid changing the shared `ProceduralModule` for a comparison. This example is a minimal fixed-up-vector gait, not a full locomotion system: it has no obstacle or slope adaptation, target reachability check, time-based velocity prediction, multi-leg support, networking policy, or limit enforcement. It has been tested on a detached Dino Auto clone with controlled ground samples, not rendered in live play.

## Experimental footstep target trajectory

`IK.StepTrajectory.new` generates one continuous swing target from a caller-supplied start to a target in the same coordinate frame. It accepts numeric three-element arrays, a nonzero up direction, a nonnegative lift height and a positive duration in seconds. Horizontal travel and lift have zero endpoint velocity. `advance(dt)` returns a fresh position array, completion flag and normalized progress; `sample(time)` evaluates without changing the trajectory's elapsed time. Calls clamp at the endpoint. Create a new trajectory for the next step using the current position as its start.

```lua
local swing = IK.StepTrajectory.new({
    start = {foot.X, foot.Y, foot.Z}, target = {goal.X, goal.Y, goal.Z},
    up = {0, 1, 0}, height = 0.5, duration = 0.3,
})
-- Call from your explicitly scheduled update loop:
local point, done = swing:advance(dt)
local result = leg:solve(Vector3.new(point[1], point[2], point[3]))
```

This is a target generator, not a complete gait or a fix for Dino Auto: it does not select footholds, raycast, coordinate legs, manage IK ownership, or ensure the target is reachable. The caller handles the update loop, target selection, diagnostics and animation conflicts. Isolated Motor6D and Bone fixture chains have followed sampled targets; live or visible motion has not been validated.

The separate behavior coordinator can route named vector impulses to `IK.FootstepBehavior.new`. Its `start`, `up`, `height`, and `duration` use the same conventions as `StepTrajectory`; `impulse` names the event. Its output contains `position`, `moving`, and `progress`. An event during a swing begins a new swing at the current position; if several arrive in one update, the last target wins. The behavior holds the final target until another event. For example:

```lua
local coordinator = IK.Actor.new({behaviors = {{
    name = 'leftFoot', type = 'footstep', options = {
        start = {foot.X, foot.Y, foot.Z}, up = {0, 1, 0},
        height = 0.5, duration = 0.3, impulse = 'StepLeft',
    },
}}}, {footstep = IK.FootstepBehavior.new})
coordinator:impulse('StepLeft', {goal.X, goal.Y, goal.Z})
-- In the caller's update loop:
local output = coordinator:step({}, dt)[1].value
leg:solve(Vector3.new(output.position[1], output.position[2], output.position[3]))
```

This coordinator is independent of the generated direct-control actor; it does not yet merge behavior results or own the IK chain. A step target impulse must be a finite three-number array. The general coordinator retains impulses if a behavior throws, so handle invalid messages deliberately rather than blindly retrying.

For an authored chain, `IK.createFootstepChain(definition, options)` combines one swing behavior and one configured IK chain. Newly generated controllers also expose `controller.openFootstep(name, options)`. Supply the current endpoint's **world position** as `start` and a world-space `up` vector; a wrong starting position causes an initial jump. For example:

```lua
local stepper = controller.openFootstep('Leg', {
    exclusive = true, start = endpoint.WorldPosition, up = Vector3.yAxis,
    height = 0.5, duration = 0.3,
})
stepper:requestStep(goal.WorldPosition)
-- Call in your selected update loop:
local state = stepper:step(dt)
print(state.moving, state.progress, state.solve.error)
-- Disconnect the loop first, then restore the chain:
local conflicts = stepper:destroy()
```

Repeated requests before an update use the last target; requests during a swing retarget from the current target position. This controller holds the last target and solves it on each call, including while idle. It does not connect a loop, raycast, select steps, coordinate legs, or disable external writers. `step` advances the target before solving, so an error from the solver can leave its target state advanced; shut down deliberately rather than retrying blindly. `destroy` restores owned transforms where possible and returns conflicts. Existing generated controller scripts are deliberately not overwritten and may lack `openFootstep`; use `IK.createFootstepChain` directly or add the method to your editable controller. Fixtures cover Motor6D and Bone chains, not animated or skinned rigs.

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


## Generating an input template

For a hinge joint, enter a named control or impulse and optionally a Roblox `KeyCode` name (for example `E` or `ButtonA`) in the joint editor, then save the joint. Create or refresh the model's actor definition before choosing **Create disabled input template for model**. The template is a disabled `EditRigIKInputTemplate` under the model; keys for the same named action are grouped. A key assigned to different actions is rejected. Existing templates are never overwritten: remove or rename an old template deliberately before regenerating it. This is a snapshot, so refresh and regenerate after changing mappings. The generated template has keyboard/gamepad bindings, not touch buttons.

For a local player, clone the template beneath that player's `PlayerScripts`, bind it while disabled, then enable it after the actor is ready:

```lua
local context = model.EditRigIKInputTemplate:Clone()
context.Parent = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local inputs = IK.InputBindings.new(actor)
local profile = inputs:bindProfile(context)
context.Enabled = true

-- During shutdown, disconnect the actor update loop first:
context.Enabled = false
profile:destroy()
inputs:destroy()
context:Destroy()
-- Then stop or destroy the actor.
```

A template does not start the actor or establish network authority. Coordinate the actor update loop and any Animator, IKControl, or other joint writers; decide explicitly how the server validates and replicates player actions. Binding a hold initializes its named control to zero. This path has been exercised using scriptable input in Studio, but real device input and multiplayer have not yet been verified.

## Binding Roblox InputActions

`IK.InputBindings.new(actor)` connects existing Bool `InputAction` instances to the actor's named controls. The action's `InputContext` and `InputBinding` objects still define the actual keyboard, gamepad, or GUI inputs. Set those up on the client using Roblox's [Input Action System](https://create.roblox.com/docs/input/input-action-system). For example, in a LocalScript after starting the actor:

```lua
local inputs = IK.InputBindings.new(actor)
inputs:bindHold(actions.Bite, 'Jaw', 1)       -- 1 while held; 0 when released
inputs:bindImpulse(actions.Snap, 'JawImpulse', 1) -- once on each press
-- In the chosen update loop: actor:step(dt)
-- On cleanup, disconnect the loop and then:
inputs:destroy()
controller.stop()
```

`bindHold` synchronizes an already-held action immediately and accepts a value in `[-1, 1]`. It resets an active control to zero on release or cleanup. `bindImpulse` sends a finite scalar or three-number vector only on a new press; its meaning is defined by the receiving behavior. Both return an individual handle with `destroy()`. A binding closes if its action is destroyed or changes away from Bool; one manager rejects duplicate hold bindings for the same control. Other managers and scripts can still write that control, so the caller must coordinate them. Destroy bindings before destroying the actor. This does not create input actions or UI, connect the actor update loop, authorize server actions, or replicate input. A Studio fixture used scriptable InputBindings; actual keyboard, gamepad, touch and multiplayer behavior remain unverified.

## Experimental direct joint control

`IK.JointDrive.new(options)` is a behavior factory for the actor registry. Each binding has a `name`, scalar `control`, optional scalar `impulse`, lower/upper angles in radians enclosing zero, and a positive `frequency` in inverse seconds. A control in `[-1,1]` maps to the corresponding angular limit; out-of-range controls are clamped. An impulse adds angular velocity (radians/second) to a critically damped offset; input and accumulated velocity are clamped to ±100. The combined output is clamped to the joint limits. The behavior returns a map of joint names to angles and never modifies instances itself.

The driver commits its internal joint states only after all of its inputs for a step validate. A rejected control or impulse therefore does not partially advance earlier joints. This guarantee applies to the driver itself: the actor coordinator cannot roll back other behaviors that already ran, or adapter writes that fail later.

`IK.JointAdapter.new(bindings, {exclusive=true})` captures each `Motor6D.Transform` or `Bone.Transform` and applies angles relative to that captured transform around the configured local `Vector3` axis. Call `adapter:apply(actor:step(input, dt)[1].value)` when this is the first behavior result. It validates all inputs and detects an externally changed transform before writing. `adapter:destroy()` restores transforms it last wrote, leaves externally changed transforms alone, and returns their names. Ownership checks use a tolerance and are not a lock; the caller must ensure no Animator, IKControl, script or other adapter writes the same transforms and must choose appropriate scheduling. There is no automatic arbitration or editor connection yet. Avoid enabling this on Dino Auto's IK-driven legs without first resolving ownership.

In Studio Edit mode, isolated tests created unparented Motor6D and Bone instances, exercised controls, an impulse, application and restoration, and checked that external changes are reported without being overwritten. These checks do not establish behavior in an animated or networked actor, skinned mesh deformation, a packaged module, or a playtest.

## Creating an idle direct-control actor

In the prototype editor, save hinge metadata on each Motor6D or Bone, then select their containing Model and press **Create direct-control actor from selected model**. The joint fields include control name, impulse name and impulse damping frequency (0.01–100 inverse seconds); blank names default to the joint name and joint name plus `Impulse`. Multiple joints may share a control or impulse name. These settings are used by the direct-control actor, not by the IK chain solver. The builder requires unique configured joint names and ranges that contain zero; it rejects ball limits and unknown metadata versions. It creates an `EditRigIKActor` folder of ObjectValue references and an editable `EditRigIKController` ModuleScript in the model. It does not replace existing objects of those names. The definition is a snapshot. After editing joint metadata, select the model and choose **Refresh selected model actor settings** to update existing references from their joints; this replaces settings manually edited on those references, but preserves the references and controller script. Restart an active actor to load the refreshed values. Newly configured joints are not added by refresh; adding or removing bindings still requires rebuilding the definition. The installed plugin toolbar and panel opening were confirmed; its individual controls have not yet been tested interactively.

Install the bundled runtime using the editor button, or place the separately built `EditRigIKRuntime` ModuleScript in ReplicatedStorage. From a script running on the intended side, after ensuring no Animator, IKControl or other writer owns the configured joints:

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

The runtime rejects overlapping claims from its own actors and chains, but this is not a lock against external writers. Existing Animator, IKControl, and other writers must be managed by the caller. Pass an optional world-space `Vector3` as `pole` in `chain:solve(target, options)`; the adapter converts it into the root frame. The adapter rejects translated joint `Transform`s, disconnected chains, changed rest geometry, and externally changed transforms. The solver permits individual zero-length links but rejects chains with no nonzero links. It applies the best result even when `converged` is false, so callers must inspect diagnostics. Restore reports indices of joints overwritten by someone else and leaves those transforms alone. It does not connect an update loop or manage replication. Animator timing, real physics, skinned mesh deformation, live Dino Auto and pole behavior on real rigs remain unverified. The joint limit axes in the example are illustrative only.


## Authoring and opening an IK chain

In the editor, save hinge or ball settings on every joint in the intended chain. Select the root joint and click **Set root joint**, select the end joint and click **Set end joint**, then select a regular Attachment directly under the final Motor6D's Part1 or final Bone and click **Set endpoint attachment**. Enter a chain name, CCD iteration limit, tolerance in studs, and maximum correction per iteration in degrees, then click **Create idle IK chain definition**. The default correction is 180 degrees; old saved chains use that default. The builder requires a single directed path and rejects ambiguous, cyclic, disconnected, mixed-type, or unconfigured chains. It creates a snapshot under the containing model's `EditRigIKChains` and an idle controller if one does not already exist. It does not overwrite an existing chain.

Alternatively, select an existing IKControl and choose **Capture chain from selected IKControl**. Discovery is read-only: for a BasePart root it includes the unique incoming Motor6D and follows a unique enabled Motor6D path to the end; for Bones it follows the direct Bone hierarchy. A regular Attachment end effector or pole in the model is captured when available. A BasePart end requires an explicit endpoint Attachment, and every discovered joint still needs saved limit metadata. The existing IKControl stays active; its offsets, target, smoothing and orientation behavior are not copied. The custom solver is position-only, so this does not promise equivalent behavior or safe simultaneous control. The discovery code was checked against Dino Auto's two leg controllers; the button has not yet been tested interactively.

After capturing the end joint, you can enter a comma-separated local X, Y, Z offset in studs and choose **Create endpoint at entered local offset**. This creates `EditRigIKEndpoint` under the final Motor6D's Part1 or final Bone, with undo waypoints, and captures it for chain creation. The offset is chosen by the creator and should be checked on the rig; it is not inferred from the anatomy or an existing IKControl offset. The action refuses a duplicate name or a zero-length final link. It leaves the existing IKControl unchanged. The preparation code was tested with both joint types; the button and undo flow still need interactive Studio checks.

Optionally capture an Attachment in the same model as the pole before creating the chain. Its current `WorldPosition` is read on each solve; a world-space `pole` override can be supplied to `solve`. The captured pole is associated when creating the chain; the current editor does not yet change an existing chain's pole. Confirm attachment frame behavior on animated Bones before using one as a pole. The pole is a bend preference and may be degenerate or blocked by constraints; inspect `poleStatus`.

To tune an existing chain, select its definition folder inside `EditRigIKChains`, choose **Load selected chain settings**, edit the three solver values, and choose **Save settings to selected chain** while that folder remains selected. Saving preserves its endpoint, joint references and limit snapshots. After editing joint limit metadata, select the chain definition and choose **Refresh selected chain limits from joints**; all referenced joints must have valid metadata and form a connected chain. Close and reopen any active runtime chain to use updated settings or limits. These editor buttons have not yet been verified interactively.

The experimental **Open selected chain clone preview** creates a script-free clone inside a `ViewportFrame`. Enter a world-space target offset in studs and choose **Solve clone preview**; the displayed result reports convergence and pole status. A red marker indicates the requested target and a green marker the solved endpoint; the camera reframes to include the target. The markers may overlap at convergence. Motor6D parts in the clone are posed using forward kinematics; Bones use their transforms. Enabled JointInstances and WeldConstraints connected to moved chain parts follow using their captured relative poses, without simulating their animation or physics. Other constraint types, ambiguous rigid cycles and external attachments may not follow accurately. Closing the preview, closing the plugin panel, or unloading the plugin destroys the clone. It rejects ambiguous chain paths, uncloneable models, and models over 5,000 descendants. The clone is a static snapshot: external controllers, animation, physics and live updates are not simulated. Refresh limits before opening, and close/reopen the preview after editing a definition. Source-level Studio fixtures verified isolation and cleanup for both joint types and an isolated Dino leg clone; the actual panel rendering has not yet been verified.

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

Opening does not start an update loop or disable an IKControl. Same-runtime overlap is rejected, but the creator must manage external writers, scheduling and networking. Saved limits are snapshots; refresh the definition after editing a joint. Changing or reparenting the endpoint after opening requires closing and reopening the chain. AnimationConstraint rigs and external conflict resolution are not implemented. The installed toolbar and panel opening were confirmed, but the authoring controls and packaged runtime have not been tested interactively. Source-level Studio tests used isolated Motor6D and Bone fixtures, including ambiguous path and endpoint-change checks, not a live dinosaur or skinned mesh.
