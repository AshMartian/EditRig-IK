# Code tour

This map covers the committed prototype. Start with the editor for Studio UI,
then follow the builder for saved data or the runtime for motion in an experience.

## From a click to a moving rig

1. [`Editor.server.luau`](../src/plugin/Editor.server.luau) creates the Studio
   panel, listens to selection and button events, and owns temporary viewport
   helpers. Changing a field updates a draft; saving writes joint attributes.
2. [`JointAuthoring.luau`](../src/plugin/JointAuthoring.luau) validates and
   saves limits and control settings. [`DefinitionBuilder.luau`](../src/plugin/DefinitionBuilder.luau)
   copies saved settings into an actor definition. [`ChainBuilder.luau`](../src/plugin/ChainBuilder.luau)
   resolves a joint path and creates a chain definition. These are saved recipes,
   not running animation.
3. A game script explicitly starts [`GeneratedController.luau`](../src/plugin/GeneratedController.luau)
   or uses [`Runtime.luau`](../src/runtime/Runtime.luau). Runtime creates the
   actor or chain adapter, coordinates its own claims, and delegates calculations
   to the shared solver. Callers must arrange updates and cleanup and resolve
   conflicts with Animator, IKControl and other writers.

## Find a feature

| Need | Start here | Responsibility |
| --- | --- | --- |
| UI and Studio events | [Editor](../src/plugin/Editor.server.luau), [PanelComponents](../src/plugin/PanelComponents.luau) | Panel, selection, callbacks and cleanup |
| Joint markers | [RigOverlay](../src/plugin/RigOverlay.luau), [OverlaySelection](../src/plugin/OverlaySelection.luau) | Temporary markers and selection policy |
| Hinge editing | [HingeLimitHandles](../src/plugin/HingeLimitHandles.luau), [LimitDraft](../src/plugin/LimitDraft.luau) | Viewport drag and unsaved values |
| Chain choice | [ChainDiscovery](../src/plugin/ChainDiscovery.luau), [ChainInference](../src/plugin/ChainInference.luau), [ChainBuilder](../src/plugin/ChainBuilder.luau) | Discover paths, report ambiguity, save choices |
| Ghost simulation | [WorldGhostSession](../src/plugin/WorldGhostSession.luau), [PreviewSession](../src/plugin/PreviewSession.luau) | Disposable clones; the editor ends sessions |
| IK math | [Solver](../src/shared/Solver.luau), [Limits](../src/shared/Limits.luau), [CircularHinge](../src/shared/CircularHinge.luau) | Plain-table math and limit calculations |
| Rig writes | [ChainAdapter](../src/runtime/ChainAdapter.luau), [JointAdapter](../src/runtime/JointAdapter.luau), [Ownership](../src/runtime/Ownership.luau) | Runtime transforms and local ownership claims |
| Ground contact | [SurfaceProbe](../src/runtime/SurfaceProbe.luau), [SurfaceFrame](../src/runtime/SurfaceFrame.luau), [SurfaceOrientation](../src/runtime/SurfaceOrientation.luau) | Sample surfaces and compute orientation |

`src/plugin` contains Studio tools and generated templates. `src/runtime`
contains game-facing adapters and behaviors. `src/shared` contains validation
and numerical code used in both packages. `plugin.project.json` and
`runtime.project.json` describe how Rojo assembles those sources; moving a file
also requires updating the relevant package and fixture bundlers.

The editor is still a large entry point. Its section comments mark overlay,
authoring, chain-capture and preview lifetimes; extracting those pieces into
smaller modules requires care because its callbacks share selection and draft
state. See [runtime conventions](runtime.md) for coordinate frames and API
contracts, and [Studio fixtures](studio-source-tests.md) for tests.
