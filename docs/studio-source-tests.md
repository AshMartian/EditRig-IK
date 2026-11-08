# Running source-level Studio fixtures

These fixtures run the current local source as Luau in **Studio Edit**. Most create detached instances and dispose of them on success. `SurfaceProbe` temporarily adds a test folder with anchored parts to Workspace and removes it even if an assertion fails; an interruption may require removing `Workspace.EditRigIKSurfaceProbeFixture` manually. They do not load the installed plugin, exercise its complete interface, simulate real pointer input, or prove that viewport adornments are rendered correctly. Use the installed-plugin checks in [debugging.md](debugging.md) separately.

From the project root, generate one fixture without network access:

```sh
python3 tools/bundle_studio_test.py ViewportTargetHandle > /tmp/editrig-studio-fixture.luau
```

The accepted names are `PanelComponents`, `JointAuthoring`, `ViewportTargetHandle`, `WorldGhostSession`, `ChainDiscovery`, `AxisGizmo`, `HingeLimitHandles`, `SavedLimitOverlay`, `SurfaceProbe`, `SurfaceContactGizmo`, `ConfiguredOrientation`, `OrientationChain`, and `SurfaceOrientation`. The program fails for unknown names; it writes the generated Luau to standard output and does not alter the place. Generate a fresh bundle after source changes. Paste or submit the **entire** generated Luau to the Studio Edit command interface and inspect Output. A passing fixture prints `Studio source fixture <name> passed:` followed by the fixture result; an assertion or other error is a failure. The generated code refuses to run outside Edit mode.

Check the bundler itself locally with:

```sh
python3 -m unittest discover -s tests -p 'test_studio_bundle.py'
```

`SurfaceProbe` tests Workspace raycast filtering with the source and ghost excluded, slope/contact calculation, and invalid-input handling. `SurfaceContactGizmo` checks guide positioning, visibility, and disposal on detached instances; it does not establish that the guides render correctly in the viewport.

`AxisGizmo` checks joint rest-frame calculations for Motor6D and Bone rigs and signed ball twist-arc geometry. `HingeLimitHandles` exercises draft edits and handle placement with programmatically supplied rays; it does not establish that a person can select or drag a handle in the installed plugin. `JointAuthoring` verifies limit and control metadata can be validated and saved independently on detached Motor6D and Bone instances.

`ConfiguredOrientation` checks that saved chains pass attachment orientation and requested pose options through. `OrientationChain` checks Motor6D and Bone endpoint orientations, including speed-capped diagnostics. `SurfaceOrientation` checks the surface-frame adapter, configured sole axes, strength, degeneracy, and input validation. These use disposable instances and do not verify an installed runtime, animated mesh, contact motion, or real-time performance.

The fixtures do not validate Play transitions, a real user's handle drag, skinned mesh rendering, or performance. Those require separate Studio checks with representative rigs and a careful cleanup of temporary scene objects.

`tests/studio/InstalledAutoViewport.integration.luau` is a separate installed-plugin smoke test: run it in Studio Edit with the panel open and idle. It temporarily selects a disposable model and joint, checks automatic controls and absence of source writes, then restores the previous selection and draft fields. It does not inject pointer or keyboard input. If interrupted, remove `Workspace.EditRigIKAutoModeFixture` and restore the selection manually.

## Rojo-built runtime contact fixture

The following builds `runtime.project.json` with the local Rojo executable into a temporary XML package and emits a Studio program that reconstructs its root and child ModuleScripts, requires the root, and exercises surface contact against actual Workspace parts. The sources and hierarchy come from Rojo's package, rather than loose source wrappers.

```sh
ROJO_BIN=/path/to/rojo python3 tools/bundle_packaged_runtime_test.py > /tmp/editrig-packaged-runtime.luau
```

Run the entire generated program in Studio Edit and inspect Output for `Packaged runtime Studio fixture passed:`. It refuses to run if `Workspace.EditRigIKPackagedRuntimeFixture` already exists and removes its own temporary folder on success or assertion failure. If execution is forcibly interrupted, inspect and remove that folder before retrying. This checks the Rojo-built runtime module tree, real raycasts and a detached orientation solve, not the installed plugin, animated gait integration, or Play mode. The bundle-generation regression tests run with `ROJO_BIN=/path/to/rojo python3 tests/test_packaged_runtime_bundle.py`.

## Dino Auto Play turn fixture

`tests/studio/PlayDinoFootTurn.integration.luau` requires the open place's `Workspace.Dino Auto` and a disabled, archivable Script named `DinoAutoBodyRelativeTargetsTemplate` in ReplicatedStorage whose Source is exactly [the experiment](../examples/DinoAutoBodyRelativeTargets.server.luau). Create that uniquely named temporary template in Edit mode only if it does not already exist. Start Play, execute the fixture in the **Server** data model, inspect its returned comparisons, then stop Play and remove the temporary template in Edit mode. It clones and sanitizes the rig before parenting its temporary fixture, tests both fixed and body-relative target rotations and an external-writer conflict, and cleans up on success or assertion failure. If execution is forcibly interrupted, inspect `Workspace.EditRigIKDinoFootTurnFixture` in the Play server. The fixture isolates turning rather than proving a planted-foot gait, terrain alignment or all joint behavior.
