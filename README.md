# EditRig IK

A companion Studio plugin and reusable IK runtime in early prototype development. The installed RigEdit plugin is not modified. The project source is this directory; the target experimental model is `Workspace.Dino Auto` in Prehistoric Rumble.

## Current prototype

The docked editor accepts one selected `Motor6D` or `Bone` and saves validated hinge or ball-limit metadata as attributes, with undo waypoints. **These attributes do not constrain an IK solver yet.** The shared module contains experimental quaternion hinge and swing/twist clamping math. There is no runtime solver, chain discovery, preview, visualization or script generation yet. Dino Auto and its existing scripts have not been changed. See [design and investigation](docs/design.md).

## Build and validation

Requires Luau CLI 0.746 and Rojo 7.7.1. Set `LUAU_BIN`, `LUAU_COMPILE_BIN` and `ROJO_BIN` to their executables, then run:

```sh
python3 tools/build.py
```

The build runs portable Luau tests, compiles the sources, builds a staged plugin, verifies its binary header, and replaces `build/current` only after all checks pass. `build/current/manifest.json` records source fingerprint, tool settings, checks and artifact hash; it is generated and ignored. Output is experimental and has not been verified or installed in Studio. Existing game assets, captures and release packages are not stored here.

The default authoring values are placeholders, not anatomically correct dinosaur limits. Axis and rest-frame conventions need Studio verification on actual Motor6D and Bone rigs before use.
