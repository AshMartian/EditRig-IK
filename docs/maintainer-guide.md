# Maintainer guide

This guide covers the public GitHub repository. It does not publish the plugin
to the Roblox Creator Store. The current editor is experimental; describe what
was actually tested whenever you publish a build or documentation.

## Choose the exact source to release

The public repository and any separate local Studio development checkout can
be at different commits or have uncommitted changes. A tag builds **only the
committed tree it points to**. Before releasing, reconcile the intended changes,
review the diff, and check that the commit you plan to tag is on GitHub. Do not
assume an installed local plugin matches that commit.

1. Review open changes and confirm the intended commit and repository:

   ```sh
   git status --short --branch
   git log -1 --oneline
   git remote -v
   ```

2. Run `python3 tools/build.py` with the tool paths described in the
   [build instructions](../README.md#build-from-source). Confirm the successful
   GitHub Actions build for the intended commit too. The build executes portable
   tests and compiles Studio fixtures; it does **not** run Studio fixtures,
   exercise the installed interface, or validate a rig in Play mode.
3. On representative copies, run the applicable [Studio checks](studio-source-tests.md)
   and manually test the installed plugin, viewport interactions and Play
   behavior relevant to the release. Record what passed and what remains
   unverified. Do not imply CI performed Studio checks.
4. Review the [tutorials](tutorials/README.md), screenshots, known limitations
   and release notes against that same build. Remove private data or third-party
   content that is not authorized for public distribution.

## Publish a GitHub release

The [build workflow](../.github/workflows/ci.yml) runs on pushes and pull
requests. A **pushed version tag** additionally runs its release job after the
build succeeds. The workflow accepts tags such as `v0.2.0` and
`v0.2.0-alpha.1`; a tag containing a hyphen creates a prerelease. This workflow
publishes automatically, so do not push a release tag until you intend to make
its assets public. Tags are release milestones, not routine build numbers.

After the intended commit has been reviewed and pushed, replace the example
version and SHA below with a new, unused version and the actual reviewed commit:

```sh
git tag v0.2.0-alpha.1 <reviewed-commit-sha>
git push <github-remote> refs/tags/v0.2.0-alpha.1
```

Use the remote name confirmed with `git remote -v`; do not literally type the
angle-bracket placeholders. Avoid moving or reusing a published tag. The job
builds the tagged commit, uploads the build as a temporary Actions artifact,
creates a draft release, uploads its four assets, and publishes the draft. Only
the release job has `contents: write` permission. Regular branch and pull
request builds do not publish a release; their Actions artifacts expire after
14 days. Rerunning an already published release job is not a release update.

Check the run and the resulting public release:

```sh
gh run list --repo AshMartian/EditRig-IK --limit 10
gh run watch <run-id> --repo AshMartian/EditRig-IK --exit-status
gh release view v0.2.0-alpha.1 --repo AshMartian/EditRig-IK
mkdir -p /tmp/editrig-release-check
gh release download v0.2.0-alpha.1 --repo AshMartian/EditRig-IK --dir /tmp/editrig-release-check
(cd /tmp/editrig-release-check && sha256sum --check SHA256SUMS.txt)
```

Use a fresh empty download directory for each check, and replace the example
tag and `<run-id>`. Confirm `EditRigIK.rbxm`, `EditRigIKRuntime.rbxm`,
`manifest.json`, and `SHA256SUMS.txt` are present; compare the release's source
commit with the reviewed commit and check the prerelease label. The manifest's
`studio_validation` records the automated build's scope, not manual test
results. Update the release notes with actual manual checks and limitations.
Checksums detect a changed download when compared with a trusted checksum;
they do not independently prove its origin.

If the run fails, inspect the Actions log first. A failed build does not run
the release job. A failure during upload can leave a draft release: inspect
its tag and all assets. If completing it manually, verify every asset and its
checksum before publishing; otherwise remove only the incomplete **draft** and
rerun the failed job. Do not delete or replace an already published release or
retag it as a routine retry. If a published release needs correction, document
the problem and make a new version.

## Update the tutorials and screenshots

The source of truth is the Markdown under [`docs/tutorials/`](tutorials/README.md)
in the main repository. Update it in the same change as any affected plugin
behavior or UI labels. Use the following process:

1. Identify the exact supported build or version and the reader's goal. Walk
   through each instruction in Studio where possible; distinguish verified
   actions from source-only or historical observations.
2. Update button names, prerequisites, expected results, troubleshooting,
   links and version references. Explain which actions save data or modify a
   place, and which operate only on a temporary preview.
3. Use real Studio screenshots when documenting actual behavior. Check they
   depict the documented version, are legible and have descriptive alt text.
   Keep historical captures labeled as such; never present design concepts as
   implemented features. Review screenshots for private information and asset
   rights before committing them. Preserve original evidence as appropriate.
4. Check Markdown links and images on GitHub, review the diff, and have a
   second person follow the tutorial when practical. Explicitly note anything
   that could not be checked in Studio. The regular CI build does not validate
   tutorial accuracy or rendered screenshots.

## GitHub wiki

The repository's wiki is enabled, but no first page has been created yet. The
wiki is a separate Git repository; there is **no automatic synchronization**
with `docs/tutorials/`. To avoid two conflicting copies, keep full tutorials in
the main repository and use the wiki as a small navigation page linking to the
canonical tutorials and releases. Update those links when paths change.

To initialize it, a maintainer can open the repository's **Wiki** tab on GitHub,
create the first `Home` page with links to the main repository tutorial index
and release page, and save it. After that first page exists, the wiki can be
edited on GitHub or cloned separately:

```sh
git clone https://github.com/AshMartian/EditRig-IK.wiki.git
cd EditRig-IK.wiki
# Edit Home.md, review changes, commit, and push to the wiki's default branch.
```

Check `git status` and `git remote -v` before pushing: this is the wiki
repository, not the plugin repository. Use full GitHub URLs for links from the
wiki to files or images in the main repository; a tutorial's relative links are
relative to its own repository and do not automatically transfer to the wiki.
Verify the rendered wiki page and links after publishing. Wiki edits have their
own Git history and do not run the main repository's CI. GitHub documents
[wiki creation and local editing](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages)
and [wiki images and links](https://docs.github.com/en/communities/documenting-your-project-with-wikis/editing-wiki-content).
