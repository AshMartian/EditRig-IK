# Errors and access limitations

## [ERR-20261107-001] native_studio_ui_access

**Logged**: 2026-11-07
**Priority**: high
**Status**: pending
**Area**: tests

### Summary
The available computer-use session exposes browser surfaces but no native application inventory or window API, so the Studio plugin panel cannot be directly inspected or operated through that session.

### Context
`cua.getState()` returned no native apps and `cua.listWindows` was unavailable. Studio MCP's screen capture returned the game viewport without the Studio plugin panel. A user-provided screenshot showed the panel. Source-level Studio MCP tests remain available, but they do not replace interactive panel testing.

### Suggested action
Use a supported native desktop-control connection when available, and verify a fresh panel screenshot and interaction before claiming the UI is tested. Until then, report the limitation and use user-provided captures for visual evidence.

### Metadata
- Reproducible: yes in this session
- Related Files: docs/debugging.md
