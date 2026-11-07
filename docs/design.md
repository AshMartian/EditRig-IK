# EditRig IK companion — working design

## Intent
Build a companion Studio plugin for authoring procedural IK on existing rigs, including both Motor6D and skinned Bone chains. RigEdit remains independently installed; this project does not patch or depend on its private code. Dino Auto is the intended experimental rig, but its live hierarchy and existing solver remain uninspected until Studio connects.

## Architecture
- A docked editor selects a model, identifies ordered Motor6D or Bone chains, displays them, and edits per-chain and per-joint settings. The editor visualizes local axes, limits, target and pole, warns about ambiguous or disconnected chains, and supports reversible preview.
- Versioned configuration belongs to the rig and contains explicit joint identity, rest frame, limit type and local axis, hinge lower/upper angles or swing cone and twist range, solver choice, iterations, tolerance, weight, target, pole, and update policy. Validate before saving or generating; do not silently replace malformed settings.
- A shared runtime exposes a documented API for loading a configuration, setting a target and pole, enabling/disabling and stepping the solver, querying diagnostics, and destroying/restoring state. Rig-specific adapters convert Bone or Motor6D animation transforms to a shared local rotation representation and apply results; ownership and animation update order must be explicit. Generated user scripts are thin examples referencing runtime modules, never opaque source blobs.
- Limits are evaluated in each joint's stored rest frame. Hinge is signed rotation around its configured local axis; ball limits split swing and twist. Solvers apply limits during each iteration, not only after convergence. Unreachable targets, straight-chain singularities, antiparallel directions and zero-length links require bounded, deterministic handling and diagnostics.

## Prototype and verification
Start with portable quaternion limit math and tests, then a working editor, runtime adapters and solver. The prototype is experimental: no claim of rig compatibility or glitch resolution until tested inside Studio on Dino Auto. Unit tests cover pure math, while Studio integration tests must cover transforms, actual poses, Animator interaction, frame ordering, both rig types, persistence, preview restoration and generated scripts. No automatic changes to the installed RigEdit plugin or live rig.

## Open decisions
Dino Auto's rig types, scale, naming, solver and reproduction are unknown. Solver algorithm, default limits and initial UI layout remain design choices to verify against the real rig; they are not assumptions about existing behavior. No physical constraints are created merely to pretend that a custom solver respects limits.

## Dino Auto inspection (2026-11-07)
The experimental model is `Workspace.Dino Auto` in Prehistoric Rumble, place 93747181848349. Its legs are Motor6D chains, not Bone chains. Two enabled Transform IKControls under the Humanoid run from each `Leg 1` to its `Foot`; poles are assigned by the model script at runtime. A read-only descendant scan found no HingeConstraint or BallSocketConstraint in this model. The existing built-in IKControl is separate from the custom solver planned here, and would need explicit ownership arbitration before a custom solver drives the same joints.

`ProceduralModule:IkLegStep` initializes PreviousPos to world origin and moves targets in two discrete jumps, midpoint then endpoint. The outer script alternates legs on 0.5-second waits. These are concrete candidates for visible discontinuity, but no reproduction or visual test has established causation. The model has not been modified. Preserve the original and do not change the shared ProceduralModule when experimenting with the clone without verifying impact on Dino base.
