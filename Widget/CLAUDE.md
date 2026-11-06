# Widget (Snapper)

Notes for working on the `BufferSnapWidget` extension. Repo-wide rules are in the root `CLAUDE.md`; the data flow is
in [`docs/architecture.md`](../docs/architecture.md).

## What the extension holds

| Surface | Type | Runs |
|---|---|---|
| Action button, Control Center, Lock Screen control | `OpenCaptureControl` | `OpenCaptureIntent` |
| Home Screen and Today View (`systemMedium`) | `SnapperWidget`, drawn by `SnapperWidgetView` | `OpenCaptureIntent` |
| Lock Screen widget (`accessoryCircular`) | `SnapperWidget`, drawn by `SnapperLockScreenView` | `widgetURL` to `buffersnap://capture` |

`SnapperWidgetBundle` is the extension's `@main` and lists the widget and the control. Every surface opens the app:
nothing captures from here (`docs/decisions/10-unlocked-capture.md`).

## Opening the capture screen

- **`OpenCaptureIntent` lives in `Shared/`, which both `target.yml` files compile.** Apple requires an `openAppWhenRun`
  intent in both targets. If it's only in the widget, it runs without opening the app.
- **The system runs it in the app's process**, and the log confirms that for the widget's button and the control
  (`simctl spawn "$UDID" log show` shows `BufferSnap[<pid>]` invoking `OpenCaptureIntent.perform()`). The simulator
  can't show what the device did on the Lock Screen, below.
- **The app does the navigating.** `BufferSnapApp.init` sets `OpenCaptureIntent.onRun` to `AppModel.showCapture()`, and
  in this extension's process it stays `nil` (`docs/decisions/41-open-capture-hook.md`). Don't read app-only state in
  `perform()`, since the widget compiles it too.
- **The Lock Screen widget opens a URL instead.** On an iPhone, its `Button(intent:)` opened the app where it was left,
  without running the intent. The whole circle now carries `widgetURL(AppLink.capture.url)`, which the app handles in
  `onOpenURL` (`docs/decisions/41-lock-screen-widget-url.md`). Apple's advice is the same for any widget whose tap only
  opens the app: use `widgetURL` or `Link`, not a button.
- **`buffersnap://oauth` belongs to sign-in.** `AppLink` handles only the `capture` host. Add a host there, and a test,
  for any new link.
- **A cold launch needs nothing extra.** `showCapture()` remembers nothing, because every way past sign-in ends on the
  capture screen (`docs/decisions/41-no-remembered-capture-request.md`).

## The App Group store contract

The app and the widget are separate processes that share captures through one file. Only the app writes it.

- **The file:** `captures-v2.json` in the App Group container `group.me.southp.buffersnap`. Get its URL from
  `SharedStorage.capturesFileURL()`; never build the path yourself. Both targets' `.entitlements` list the group.
- **The store:** `JSONFileCaptureStore`, one instance per use. It caches nothing and reads the file on every call, so
  the widget always sees the app's writes.
- **A missing file means no captures.** Nothing seeds it.
- **The mock captures are removed at launch.** The buttons that wrote them are gone, and the app deletes what they left
  (`docs/decisions/41-remove-mock-captures-by-text.md`).

## Every store mutation must reload the widget's timelines

The timeline is one entry with policy `.never`, so a stale count stays stale until something reloads it.

- **In the app:** the composition root wraps its store in `NotifyingCaptureStore`, which reloads after each successful
  write. Pass that store around; don't write through a bare `JSONFileCaptureStore`, or the widget's count goes stale.
- **In the widget:** nothing writes. If that changes, WidgetKit reloads the timelines by itself once an intent's
  `perform()` returns. Anything else that writes must call
  `WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)`.
- Core can't import WidgetKit (`no_ui_import_in_core`), so it holds the kind only as the string `SharedStorage.widgetKind`.

## Gotchas

- **Don't use XcodeGen's `entitlements:` key without `properties`:** `just gen` then overwrites the file with an empty
  one, and `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil ("client is not entitled" in the log).
  The targets set `CODE_SIGN_ENTITLEMENTS` to a committed file instead.
- **No per-target team, signing or version settings.** They come from the project level, so the widget's build number
  always matches the app's, which App Store Connect requires.
- `Widget/Info.plist` holds only `NSExtension`, which has no `INFOPLIST_KEY_` setting; the rest is generated.
- **Keep `.contentTransition(.identity)` on the count.** With the default transition the simulator kept drawing the
  previous count (often blurred) until the next redraw, though the timeline had already reloaded: every tap looked one
  short. Not checked on a device.
- **A test can't import an extension.** `AppTests/target.yml` compiles the widget's stateless views and `Shared/` into the
  test target, so a new view needs a line there. `AccessoryWidgetBackground` draws nothing in a snapshot, only in a real
  widget.

## Seeing it run

`AppTests/WidgetViewTests.swift` snapshots each face. To see it for real, run the app (`just run`) and add the widget
from the gallery. The control also works on the simulator: open Control Center, tap the + at the top left, then
"Add a Control". Inspect the store with:

```sh
UDID="$(just _sim-udid)"
cat "$(xcrun simctl get_app_container "$UDID" me.southp.buffersnap group.me.southp.buffersnap)/captures-v2.json"
```

Driving SpringBoard with the AXe binary from `App/CLAUDE.md` takes different commands than driving the app. These are
what worked on the iOS 27.2 simulator:

| To | Use |
|---|---|
| Tap a widget button or a menu item | `axe touch -x <x> -y <y> --down --up --delay 0.15 --udid "$UDID"` (`axe tap` didn't reliably register) |
| Enter edit mode | The same `axe touch`, with `--delay 2.0` on an empty spot |
| Change Home Screen page | `axe drag --start-x 360 --start-y 600 --end-x 40 --end-y 600 --udid "$UDID"` (`axe swipe` didn't page) |
| Open the Edit menu, then the gallery | Enter edit mode, `axe touch` Edit, wait until `axe describe-ui` lists Add Widget, then `axe touch` it. A touch sent before the menu is ready closes edit mode and lands on whatever is underneath |
| Open Control Center | `axe drag --start-x 340 --start-y 5 --end-x 340 --end-y 500 --udid "$UDID"` |
| Leave the app without killing it | `xcrun simctl launch "$UDID" com.apple.Preferences`, then `xcrun simctl terminate "$UDID" com.apple.Preferences` (`axe button home` and a bottom-edge swipe didn't leave it). This lands on the first page |

When you check the count, make the expected value differ from what's on screen, and compare it with the store's count.

To check the intent, start on the capture list, so that landing on the capture screen shows the intent did something.
