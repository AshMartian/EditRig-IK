# EditRig IK

A Roblox Studio plugin and experimental Luau runtime for exploring joint limits and procedural inverse kinematics on `Motor6D` and skinned `Bone` rigs.

> **Early prototype:** Back up your place before experimenting. Features and data formats may change. The plugin and its runtime are separate from the similarly named RigEdit plugin.

## What it does

- Inspect a model's joints and display a selectable rig overlay in the viewport.
- Author hinge and ball limits, visualize joint axes, and edit hinge limits with 3D handles and numeric fields.
- Explore inferred or manually selected IK chains and preview a constrained pose on a disposable ghost rig.
- Create experimental actor and chain definitions and use the included Luau runtime for procedural control.
- Experiment with surface-contact diagnostics and ghost orientation previews.

Features have varying levels of verification. Automatic body alignment, full procedural behavior authoring, and independent directional swing limits are not yet complete. Authored metadata does not automatically limit Roblox `IKControl` instances. See [runtime conventions](docs/runtime.md) and [design and limitations](docs/design.md).

## Tutorials and screenshots

Start with the [illustrated tutorials](docs/tutorials/README.md) for installation, joint limits, and chain previews. They include real earlier Studio captures; the interface has changed since those images were taken.

## Install a local build

1. Download `EditRigIK.rbxm` from [GitHub Releases](https://github.com/AshMartian/EditRig-IK/releases), or [build it from source](#build-from-source). Prereleases are experimental; temporary Actions artifacts are development builds.
2. In Studio, open **Plugins** and use the **Plugins Folder** control to open your local plugins directory. Copy `EditRigIK.rbxm` into that folder. Restart Studio or reload local plugins if necessary.
3. Open a place, choose **Plugins → Joint Limits**, and select a model containing `Motor6D`s or `Bone`s. Joint markers should appear when the panel is open. Choose a marker to inspect its limits.
4. Save limit edits explicitly with **Save joint limits**. Use the simulation controls to experiment on a ghost; inspect your rig and test changes before using them in an experience.

On Windows the usual folder is `%LOCALAPPDATA%\Roblox\Plugins`; on macOS it is `~/Documents/Roblox/Plugins`. For Wine-based installations, use the Plugins Folder control to find the active prefix. Roblox documents [local plugin development](https://create.roblox.com/docs/studio/plugins) and [the Plugins Folder control](https://create.roblox.com/docs/reference/engine/classes/PluginMouse). No Creator Store publication is needed.

To remove the plugin, close Studio and remove its `.rbxm` from the Plugins folder. Previously saved joint attributes and runtime objects in your places are separate from the plugin file.

## Build from source

Requirements: Python 3, [Luau 0.746](https://github.com/luau-lang/luau/releases/tag/0.746), and [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1). Install executables suitable for your platform. Set `LUAU_BIN`, `LUAU_COMPILE_BIN`, and `ROJO_BIN` if they are not on your `PATH`:

```sh
git clone https://github.com/AshMartian/EditRig-IK.git
cd EditRig-IK
export LUAU_BIN=/path/to/luau
export LUAU_COMPILE_BIN=/path/to/luau-compile
export ROJO_BIN=/path/to/rojo
python3 tools/build.py
```

On Windows, use your shell's environment-variable syntax and paths to the `.exe` files. If all three commands are on `PATH`, the exports can be omitted. Successful builds produce:

- `build/current/EditRigIK.rbxm` — Studio plugin.
- `build/current/EditRigIKRuntime.rbxm` — experimental runtime package; see [runtime documentation](docs/runtime.md) before using it.
- `build/current/manifest.json` — source fingerprint, checks and artifact hashes.

The build runs portable tests, compiles Luau sources and Studio fixtures, validates both package headers, and replaces the previous successful output only after validation. GitHub Actions runs the same build on pushes and pull requests using pinned, checksum-verified tools, then uploads temporary artifacts.

## Testing in Studio

The command-line build **does not execute Studio integration tests** or prove viewport rendering, pointer interaction, Play behavior, or compatibility with your rig. Follow the [Studio fixture guide](docs/studio-source-tests.md), and use [debugging and log locations](docs/debugging.md) for installed-plugin checks. Validate on copies of representative Motor6D and Bone rigs, including Play mode when using runtime behavior.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, test expectations, and how to report problems. The [code tour](docs/code-tour.md) maps the editor, runtime, and important handoffs; the [runtime guide](docs/runtime.md) describes data conventions and APIs.

## License

[MIT](LICENSE). Roblox and RigEdit are separate projects and are not included under this license.
