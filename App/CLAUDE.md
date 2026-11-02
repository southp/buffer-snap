# App (SwiftUI views)

Notes for working on the app's views. Repo-wide rules are in the root `CLAUDE.md`.

## UI loop

You can see the UI without the Xcode GUI in two ways: snapshot tests for one view in one state, and XcodeBuildMCP
for the whole running app.

### One view: snapshot tests (the playground)

Each view gets a snapshot test in `AppTests/` that renders it, full-screen, in each state that matters. The loop:

1. Change the view.
2. `just snapshots-record` renders every snapshot to `AppTests/__Snapshots__/<test file>/<test>.<name>.png`.
3. Read the PNG (the Read tool shows images). Compare it with what you meant to build.
4. Iterate until it looks right, then commit the PNGs with the code.

- Write snapshot tests with `assertScreenSnapshot(of:named:)` from `AppTests/Support/Snapshot.swift`. It owns the
  device (iPhone 16, the pinned `SIM_DEVICE`), light mode and the 0.98 perceptual precision. Don't pass your own.
- Name each snapshot after the state it shows (`named: "empty"`, `named: "signedOut"`), one PNG per state.
- `just test` never records. A view that renders differently fails, and the failure names two PNGs: the reference
  in `AppTests/__Snapshots__/` and the new rendering in `build/snapshot-failures/`. Read both.
- **Never re-record just to make a failing test pass.** Look at the diff first. Re-record only when the change is
  the one you intended, and list each re-recorded PNG and why in the PR's "Snapshot changes".

### Whole app: XcodeBuildMCP

For multi-screen flows (navigation, sign-in, anything a single view can't show), use the XcodeBuildMCP tools that
`.mcp.json` registers: build and run, tap, swipe, type, and screenshot the app in the Simulator.

- **Use this worktree's simulator**, never a shared one: get its UDID with `just _sim-udid`, then call
  `session_set_defaults` with `simulatorId` set to it, `projectPath` set to this worktree's `BufferSnap.xcodeproj`,
  `scheme: "BufferSnap"` and `derivedDataPath` set to this worktree's `build/DerivedData`.
- Run `just gen` first: the Xcode project is generated, so it may not exist yet.
- Don't pass `persist: true`. It writes the machine-local UDID to `.xcodebuildmcp/config.yaml` in the repo.
- Typical flow: `build_run_sim` → `snapshot_ui` (find tap targets) → `tap` → `screenshot`.
- Screenshots from a run don't replace snapshot tests. Once a screen looks right, cover its states with snapshots.
