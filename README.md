# EditRig IK

A companion Studio plugin and procedural animation framework in early prototype development. The installed RigEdit plugin is not modified. The project source is this directory; the target experimental model is `Workspace.Dino Auto` in Prehistoric Rumble.

## Current prototype

The intended framework will guide actor/avatar setup, compose reusable procedural behaviors, and expose a script-facing actor controller; see [design](docs/design.md). These framework features are not yet implemented.

The docked editor accepts one selected `Motor6D` or `Bone` and saves validated hinge or ball-limit metadata as attributes, with undo waypoints. **These attributes do not constrain an IK solver yet.** A separate experimental runtime module exposes a position-only CCD solver, quaternion hinge and swing/twist limits, and a registry-based behavior coordinator; its input is plain numeric data, not Roblox rig instances. Chain discovery, rig adapters, preview, visualization, pole control and script generation are not implemented yet. See [runtime API and conventions](docs/runtime.md). Dino Auto and its existing scripts have not been changed. See [design and investigation](docs/design.md).

## Build and validation

Requires Luau CLI 0.746 and Rojo 7.7.1. Set `LUAU_BIN`, `LUAU_COMPILE_BIN` and `ROJO_BIN` to their executables, then run:

```sh
python3 tools/build.py
```

The build runs portable Luau tests, compiles the sources, builds staged plugin and runtime packages, verifies their binary headers, and replaces `build/current` only after all checks pass. `build/current/manifest.json` records source fingerprint, tool settings, checks and artifact hashes; it is generated and ignored. Output is experimental and has not been installed or verified as a package in Studio. A read-only Studio smoke test evaluated the solver source on one numerical hinge case; it did not drive a rig. Existing game assets, captures and release packages are not stored here.

The default authoring values are placeholders, not anatomically correct dinosaur limits. Axis and rest-frame conventions need Studio verification on actual Motor6D and Bone rigs before use.
