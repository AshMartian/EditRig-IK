# Running source-level Studio fixtures

These fixtures run the current local source as Luau in **Studio Edit**. They create detached instances and dispose of them on success; they do not edit the open place. They do not load the installed plugin, exercise its complete interface, simulate real pointer input, or prove that viewport adornments are rendered correctly. Use the installed-plugin checks in [debugging.md](debugging.md) separately.

From the project root, generate one fixture without network access:

```sh
python3 tools/bundle_studio_test.py ViewportTargetHandle > /tmp/editrig-studio-fixture.luau
```

The accepted names are `PanelComponents`, `ViewportTargetHandle`, `WorldGhostSession`, `ChainDiscovery`, and `SavedLimitOverlay`. The program fails for unknown names; it writes the generated Luau to standard output and does not alter the place. Generate a fresh bundle after source changes. Paste or submit the **entire** generated Luau to the Studio Edit command interface and inspect Output. A passing fixture prints `Studio source fixture <name> passed:` followed by the fixture result; an assertion or other error is a failure. The generated code refuses to run outside Edit mode.

Check the bundler itself locally with:

```sh
python3 -m unittest discover -s tests -p 'test_studio_bundle.py'
```

The fixtures do not validate Play transitions, a real user's handle drag, skinned mesh rendering, or performance. Those require separate Studio checks with representative rigs and a careful cleanup of temporary scene objects.
