# Contributing

Thanks for helping improve EditRig IK. This is an early prototype, so small reproducible examples and clear reports are especially useful.

## Setup and validation

1. Install the Python, Luau, and Rojo versions listed in the [README](README.md#build-from-source).
2. Create a branch for your change and run `python3 tools/build.py` before and after the change. Set the executable environment variables as shown in the README if necessary.
3. Add focused regression tests for behavior changes. The build runs portable tests and compiles Studio fixtures; run applicable [Studio fixtures](docs/studio-source-tests.md) and describe any manual viewport or Play checks separately.
4. Open a pull request describing the problem, change, test commands, and any limitations or Studio checks you could not run. Do not commit generated `build/` outputs.

## Bug reports

Include the plugin version or commit, Studio version, rig type (`Motor6D` or `Bone`), reproduction steps, expected and actual behavior, and relevant Output messages. Screenshots or short videos can help; remove private project content before sharing. See [debugging](docs/debugging.md) for logging paths and collection guidance.

## Scope and safety

Do not include proprietary place files, credentials, or third-party assets without permission. Preserve original rigs while testing previews, and distinguish automated test results from observations in Studio.

## Publishing a release

After reviewing the change and validating in Studio, tag the exact commit to
release with a version such as `v0.1.0-alpha.1` and push that tag. The tag's
workflow runs the normal build first; only a successful build can publish the
`.rbxm` packages, manifest, and `SHA256SUMS.txt` on GitHub Releases. Tags with a
hyphen create prereleases. The workflow creates a draft before uploading, then
publishes it; if a run fails after creating the draft, inspect and remove or
finish that draft before retrying. Automated validation does not replace Studio
tests. GitHub Actions artifacts from regular runs expire after 14 days.
