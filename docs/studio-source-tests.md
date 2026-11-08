# Running source-level Studio fixtures

These fixtures run the current local source as Luau in **Studio Edit**. Most create detached instances and dispose of them on success. `SurfaceProbe` temporarily adds a test folder with anchored parts to Workspace and removes it even if an assertion fails; an interruption may require removing `Workspace.EditRigIKSurfaceProbeFixture` manually. They do not load the installed plugin, exercise its complete interface, simulate real pointer input, or prove that viewport adornments are rendered correctly. Use the installed-plugin checks in [debugging.md](debugging.md) separately.

From the project root, generate one fixture without network access:

```sh
python3 tools/bundle_studio_test.py ViewportTargetHandle > /tmp/editrig-studio-fixture.luau
```

The accepted names are `PanelComponents`, `ViewportTargetHandle`, `WorldGhostSession`, `ChainDiscovery`, `SavedLimitOverlay`, `SurfaceProbe`, and `SurfaceContactGizmo`. The program fails for unknown names; it writes the generated Luau to standard output and does not alter the place. Generate a fresh bundle after source changes. Paste or submit the **entire** generated Luau to the Studio Edit command interface and inspect Output. A passing fixture prints `Studio source fixture <name> passed:` followed by the fixture result; an assertion or other error is a failure. The generated code refuses to run outside Edit mode.

Check the bundler itself locally with:

```sh
python3 -m unittest discover -s tests -p 'test_studio_bundle.py'
```

`SurfaceProbe` tests Workspace raycast filtering with the source and ghost excluded, slope/contact calculation, and invalid-input handling. `SurfaceContactGizmo` checks guide positioning, visibility, and disposal on detached instances; it does not establish that the guides render correctly in the viewport.

The fixtures do not validate Play transitions, a real user's handle drag, skinned mesh rendering, or performance. Those require separate Studio checks with representative rigs and a careful cleanup of temporary scene objects.

## Rojo-built runtime contact fixture

The following builds `runtime.project.json` with the local Rojo executable into a temporary XML package and emits a Studio program that reconstructs its root and child ModuleScripts, requires the root, and exercises surface contact against actual Workspace parts. The sources and hierarchy come from Rojo's package, rather than loose source wrappers.

```sh
ROJO_BIN=/path/to/rojo python3 tools/bundle_packaged_runtime_test.py > /tmp/editrig-packaged-runtime.luau
```

Run the entire generated program in Studio Edit and inspect Output for `Packaged runtime Studio fixture passed:`. It refuses to run if `Workspace.EditRigIKPackagedRuntimeFixture` already exists and removes its own temporary folder on success or assertion failure. If execution is forcibly interrupted, inspect and remove that folder before retrying. This checks the Rojo-built runtime module tree and real raycast behavior, not the installed plugin, gameplay orientation, gait integration, or Play mode. The bundle-generation regression tests run with `ROJO_BIN=/path/to/rojo python3 tests/test_packaged_runtime_bundle.py`.
