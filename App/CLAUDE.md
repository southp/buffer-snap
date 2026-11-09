# App (SwiftUI views)

Notes for working on the app's views. Repo-wide rules are in the root `CLAUDE.md`.

## Views

Views live in `App/Views/`. `BufferSnapApp` is the composition root: it builds `AppEnvironment` and owns `AppModel`
(`@State`), and passes both to `RootView`, which shows the capture list, the only screen.

- **A screen is a container; a view is stateless.** A `…Screen` (e.g. `CaptureListScreen`) owns its Core model in
  `@State`, loads it (`.task`) and forwards actions to it. It renders through a `…View` that takes plain values plus
  closures (`CaptureListView(captures:now:onDelete:)`), so a snapshot test can show any state without async loading.
  A view with no state of its own (`SignInPromptRow`) is just the view, with its action as a closure.
- **No logic in views.** Routing, loading, deleting and every other state change belong to a Core model and its unit
  tests. A view may only map values to pixels (a kind's SF Symbol, a status's color).
- **Never read the clock or the locale in a view.** Take `now: Date` as a parameter (the screen feeds it from a
  `TimelineView`), and read `locale`/`calendar` from the environment. That's what keeps snapshots identical on every
  machine and every day. Snapshot tests count from `Capture.samplesReferenceDate`, the date `Capture.samples()` is
  dated against.

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
  device (iPhone 16, the pinned `SIM_DEVICE`), light mode, the en_US locale with a Gregorian calendar in GMT, and
  the 0.98 perceptual precision. Don't pass your own.
- Snapshot a screen's stateless view, not the screen. Wrap it in a `NavigationStack` if the screen shows it in one,
  so its title renders.
- Name each snapshot after the state it shows (`named: "empty"`, `named: "signedOut"`), one PNG per state.
- Keep truncated text out of snapshot fixtures: a truncated line can render 1px off on CI and fail a snapshot that
  passes locally (`docs/decisions/27-no-truncated-text-in-snapshots.md`). Don't lower the precision to absorb it.
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
- If a tap reports success but nothing happens, use a physical touch. The `tap` tool drives AXe with a simulated tap,
  which SwiftUI buttons and swipe actions ignored on the iOS 27.2 simulator (#3), and it can't change the style. Run
  the AXe binary bundled with XcodeBuildMCP instead (find it with
  `find ~/.npm/_npx -path '*xcodebuildmcp/bundled/axe' -type f`):
  `axe tap -x <x> -y <y> --tap-style physical --udid "$(just _sim-udid)"`. Its `axe swipe` worked as is.
- Screenshots from a run don't replace snapshot tests. Once a screen looks right, cover its states with snapshots.

## The capture file

Only the app reads and writes captures, in one file.

- **The file:** `captures-v2.json` in the App Group container `group.me.southp.buffersnap`. Get its URL from
  `SharedStorage.capturesFileURL()`; never build the path yourself.
- **The store:** `JSONFileCaptureStore`, wrapped in `CappedCaptureStore`, built once in `BufferSnapApp`. Write through
  that one: `docs/decisions/46-no-file-coordination.md` relies on there being a single writer.
- **A missing file means no captures.** Nothing seeds it.
- **The mock captures are removed at launch.** The buttons that wrote them are gone, and the app deletes what they left
  (`docs/decisions/41-remove-mock-captures-by-text.md`).

Inspect it on the simulator:

```sh
UDID="$(just _sim-udid)"
cat "$(xcrun simctl get_app_container "$UDID" me.southp.buffersnap group.me.southp.buffersnap)/captures-v2.json"
```

## App icon

`App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is generated from `docs/design/app-icon.svg`. Edit the SVG, run
`just app-icon`, and commit both. It's one 1024×1024 PNG with no transparency, and iOS derives the other sizes and the
dark and tinted looks. It's a stand-in until there's final branding (`docs/decisions/35-stand-in-app-icon.md`).
