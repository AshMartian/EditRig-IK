# EditRig IK

A companion Studio plugin and procedural animation framework in early prototype development. The installed RigEdit plugin is not modified. The project source is this directory; the target experimental model is `Workspace.Dino Auto` in Prehistoric Rumble.

## Current prototype

The intended framework will guide actor/avatar setup, compose reusable procedural behaviors, and expose a script-facing actor controller; see [design](docs/design.md). The current direct-control actor workflow is an early subset of that framework.

The docked editor accepts one selected `Motor6D` or `Bone` and saves validated hinge or ball-limit metadata as attributes, with undo waypoints. **The editor can create a direct-control actor definition and an idle controller from saved hinge settings, including named controls and impulses. The same limits can be captured in an idle position-IK chain definition.** A separate experimental runtime module exposes a position-only CCD solver, quaternion limits, a behavior coordinator, and an explicit single-axis Motor6D/Bone adapter for named controls and damped impulses; the CCD solver currently accepts numeric chains, while the direct-control actor uses Roblox joint references. An experimental explicit-chain adapter can apply position IK to Motor6D or Bone chains; the editor can resolve a selected root-to-end path. Pole preference and clone pose preview are experimental; full limit visualization and procedural behavior authoring are not implemented yet. See [runtime API and conventions](docs/runtime.md). Dino Auto and its existing scripts have not been changed. See [design and investigation](docs/design.md) and [debugging and log locations](docs/debugging.md).

## Build and validation

Requires Luau CLI 0.746 and Rojo 7.7.1. Set `LUAU_BIN`, `LUAU_COMPILE_BIN` and `ROJO_BIN` to their executables, then run:

```sh
python3 tools/build.py
```

The build runs portable Luau tests, compiles the sources, builds staged plugin and runtime packages, verifies their binary headers, and replaces `build/current` only after all checks pass. `build/current/manifest.json` records source fingerprint, tool settings, checks and artifact hashes; it is generated and ignored. Output is experimental. The observed Studio Plugins entry is a symlink to the built plugin; the toolbar and panel opening were confirmed in Studio; individual controls and the packaged runtime still need interaction tests. Isolated Studio tests evaluated the solver and drove unparented Motor6D and Bone transforms; source-level authoring and IK-chain tests also passed on unparented fixtures; no animated rig, individual editor controls, or packaged runtime module was tested. Existing game assets, captures and release packages are not stored here.

The default authoring values are placeholders, not anatomically correct dinosaur limits. Axis and rest-frame conventions need Studio verification on actual Motor6D and Bone rigs before use.

The prototype includes **Show selected joint axes and limits** for a selected Motor6D or Bone. It is intended to draw X in red, Y in green and Z in blue at the joint's rest frame, and a yellow hinge arc or ball swing-cone boundary using the values currently in the editor. Hinge arcs use an arbitrary perpendicular reference direction; ball twist bounds remain numeric only. Invalid values hide the yellow marker. The marker is temporary and should be removed when hidden, the panel closes or the plugin unloads. Geometry, frame calculations and cleanup passed Studio fixtures, but the viewport capture returned blank and marker rendering has not yet been confirmed interactively.

Select a Model and use **Inspect selected model** to list its joint types, Animators, AnimationConstraints and IKControls before configuring it. The inventory is read-only and cannot establish exclusive ownership: scripts and controllers outside the selected model may also affect the rig. The prototype does not drive AnimationConstraints.

The editor offers **Install runtime in ReplicatedStorage** for generated controllers. It refuses to overwrite an existing runtime and does not start animation. The button still needs an interactive Studio check; the cloned runtime was loaded and exercised in a detached Studio fixture.
