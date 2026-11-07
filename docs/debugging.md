# Debugging and log locations

These paths describe the Vinegar Studio prefix on this machine, checked on 2026-11-07. Other installations may use different directories. Log timestamps use UTC (`Z`). Avoid sharing entire logs without reviewing them: they can contain account, place, local path, and session information.

## Studio Output

In Studio, open **Window → Output** (or the Output button on the Script tab). Use its context/source filters to distinguish user plugin, server and client messages. Plugin startup errors and errors thrown by the generated controller or game scripts appear here when Studio reports them. Validation failures from the editor's buttons appear in its status text. The prototype does not currently write a dedicated plugin log file or implement a persistent runtime logging service.

## Interface and captures

In the current agent environment, computer-use exposes browser surfaces but not the native Studio window. Studio MCP's capture shows the 3D viewport, not plugin dock widgets or the rest of Studio's interface. A user-provided screenshot can document the complete interface; it showed the original plugin window clipped to a short floating panel on 2026-11-07. The revised editor uses a new widget ID and a taller initial floating size, but its appearance and controls still need confirmation in Studio. Logs and viewport captures alone cannot establish that those controls are visible or usable.

The current source places joint, actor, chain, and clone-preview feedback in a fixed footer beneath the scrolling editor; runtime-install and model-inspection messages remain next to their respective buttons. A fixed navigation bar jumps to Rig, Actor, Chain, and Preview sections. Check the footer after using a command, including when the button is far down the panel. Scrolling geometry was tested on a temporary Studio GUI, but this actual plugin layout has not yet been visually verified.

On 2026-11-07, an MCP capture taken to check the temporary joint-axis marker returned a blank viewport, both with and without an explicit camera. The probe was removed from CoreGui after the attempt. The axis-frame and cleanup fixture passed, but this capture does not demonstrate that the marker is visible; verify the toggle in the actual Studio window.

## Studio process logs

The application log directory is:

`/home/ash/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/ash/AppData/Local/Roblox/logs/`

Studio creates files named like `0.746.0.7461269_20261107T203402Z_Studio_2CD5F_last.log`. The suffix and timestamp change for each process, and more than one Studio process may exist. Choose the log for the active instance and time; don't assume a particular filename remains current. Startup/reload entries use `user_EditRigIK.rbxm`, `PluginFileRead`, and `PluginLoadingEnhanced`. `CreatorError`, `CreatorWarning`, and `AssistantBridge` help find script or MCP failures. `logs/crashes/` is the crash-report directory; the normal Studio log is separate.

For example, list candidate logs and search one selected file:

```sh
studio_logs='/home/ash/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/ash/AppData/Local/Roblox/logs'
ls -lt "$studio_logs"/*Studio*log | head
rg -n 'EditRigIK|CreatorError|CreatorWarning|AssistantBridge|WebSocketTraceError' "$studio_logs/REPLACE-WITH-SELECTED-LOG"
```

A log line saying a plugin was loaded or run does not prove that its UI is visible or its controls work. After correcting the package root, the user confirmed the toolbar and panel open on 2026-11-07; the individual controls remain unverified. Some `AssistantCommand` errors are from diagnostic test code and should be matched to their timestamp rather than attributed automatically to the plugin.

## Installed local plugin and source

The observed local plugin entry is:

`/home/ash/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/ash/AppData/Local/Roblox/Plugins/EditRigIK.rbxm`

At inspection it was a symbolic link to this project's `build/current/EditRigIK.rbxm`. Inspect with `readlink -f` before assuming it still points there. The separately installed RigEdit Lite plugin is managed under the account's `10900965863/InstalledPlugins/1274343708/` directory and is not this project. Don't overwrite RigEdit Lite or edit its cache as a debugging shortcut.

The canonical source is `src/`; Studio's installed artifact is generated. `build/current/manifest.json` records the source fingerprint, tool hashes, local checks and package hashes. It intentionally marks packaged Studio validation as not performed; individual source-level Studio tests are described in `runtime.md`. Rebuild using the README command before testing source changes. The stable output path can change what the symlink points to without Studio noticing immediately: the observed Studio file watcher responded to `touch -h` on the existing symlink and reloaded it. Confirm the path is actually the intended symlink before doing that, and inspect the active log for reload errors. A reload can close or reset plugin UI state.

## MCP bridge diagnostics

Studio's Assistant MCP server was observed using a local proxy and the Studio process log showed attempts to connect to `localhost:13469/studio`. The client launcher is `.../Roblox/mcp.bat` in this prefix and the executable is `StudioMCP.exe` in the active Vinegar Studio version directory. The proxy's stdout/stderr belongs to the client process/session that launched it; it is not this project's persistent log file. Studio may connect a few seconds after the proxy starts; a single immediate empty instance listing is not sufficient evidence that MCP is disabled. Studio's `AssistantBridge`/`WebSocketTraceError` records help diagnose connection failures.

`.../Roblox/StudioMCP/` contains bridge state, including an authentication token. Treat it as a credential: do not print, paste, commit or attach the token. A connection error alone does not establish that the user's MCP setting is off.

## Experimental solver diagnostics

On 2026-11-07, a read-only Edit-mode inspection of `Workspace.Dino Auto` found 22 Motor6Ds with no EditRig IK metadata, two enabled leg IKControls, and no HingeConstraint or BallSocketConstraint descendants. Neither control had a pole assigned at that moment; a game script can assign one during Play. The plugin's saved joint metadata configures its custom solver or direct actor; it does not add constraints to Roblox's existing IKControls. Roblox's [IK guide](https://create.roblox.com/docs/animation/inverse-kinematics) explains the required attachment positions and model relationship for supported IKControl constraints. Constraint counts alone do not verify that constraints are enabled, correctly aligned, or affect a particular chain. Do not infer rendered behavior from this static inspection.

`chain:solve(...)` returns `converged`, `error`, `iterations`, `endpointWorld`, `status`, `maxReach`, and `limitedJoints`. `outsideReach` is a geometric upper-bound check; listed joints were clamped during an attempted correction, which does not by itself prove why a target was missed. `chain:destroy()` and the direct adapter's `destroy()` return conflicts when a different writer changed owned transforms. These are return values, not automatically recorded logs. The caller owns any logging, update loop, and cleanup; no supplied diagnostic proves a rendered rig behaves correctly. Use isolated fixtures and verify Animator/IKControl ownership before testing a real model.

## Play-mode actor timing check

On 2026-11-07, disposable server-side Play fixtures created temporary models and cleaned them up before Studio returned to Edit mode. `tests/studio/PlayActor.integration.luau` used the generated controller's `PreSimulation` loop to drive a Motor6D and Bone; the connected physical part followed the motor with an idle Animator present. `tests/studio/PlayAnimatorConflict.integration.luau` created a temporary local animation track; when it wrote the same Motor6D, the actor detected a transform conflict, disconnected, and cleaned up. This confirms conflict detection in that fixture, not animation blending, client replication, rendered deformation, or compatibility with Dino Auto. Roblox describes the timing of Animator and Motor6D transform writes in its [Motor6D reference](https://create.roblox.com/docs/reference/engine/classes/Motor6D/Transform).

An additional synthetic Play-server fixture, `tests/studio/PlayAnimatorOverlay.integration.luau`, opted into the animated base and checked that a procedural Motor6D offset remained stable with an active Animator and restored the last base on stop. A further `PlayAnimatorAbsoluteLimits.integration.luau` fixture verified the opt-in absolute hinge projection with an active Animator. Detached tests also checked hinge twist and ball swing; skinned Bone deformation remains unverified.

On 2026-11-07, `tests/studio/PlayIKConstraintProbe.integration.luau` created a temporary three-part Motor6D chain with an active Animator and position IKControl, then removed it before returning to Edit mode. With its hinge disabled the observed relative bend was 1.5708 radians; a zero-degree hinge reduced it to 0 and moved the solved endpoint away from the target. In the same setup a -30° to +30° hinge produced an observed bend of about 0.0338 radians. This confirms that this particular zero-angle constraint affects the built-in IK solve, but does not establish angle sign mapping, that the solver must reach the boundary, or correct behavior on Dino Auto. Do not automatically convert authored limits into live physics constraints from this evidence alone. An earlier probe read `Motor6D.Transform` as identity while the IKControl's node frames had rotated; those observations should not be treated as a general guarantee about engine timing. The Play-server fixture creates a temporary local animation, does not alter Dino Auto, and does not verify rendered or multiplayer behavior.
