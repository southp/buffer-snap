# Widget (Snapper)

Notes for working on the `BufferSnapWidget` extension. Repo-wide rules are in the root `CLAUDE.md`; the data flow is
in [`docs/architecture.md`](../docs/architecture.md).

## The App Group store contract

The app and the widget are separate processes that share captures through one file.

- **The file:** `captures.json` in the App Group container `group.me.southp.buffersnap`. Get its URL from
  `SharedStorage.capturesFileURL()`; never build the path yourself. Both targets' `.entitlements` list the group.
- **The store:** `JSONFileCaptureStore`, one instance per use. It caches nothing and reads the file on every call, so
  it always sees the other process's writes. Writes are atomic.
- **A missing file means no captures.** Only the app seeds, and only when the file doesn't exist yet. A widget capture
  made before the app's first launch creates the file, so that install never gets the mock captures.
- **Two processes writing at once can lose a write.** Cross-process file coordination is deferred to the MVP.

## Every store mutation must reload the widget's timelines

The timeline is one entry with policy `.never`, so a stale count stays stale until something reloads it.

- **In the app:** the composition root wraps its store in `NotifyingCaptureStore`, which reloads after each successful
  write. Pass that store around; don't write through a bare `JSONFileCaptureStore`, or the widget's count goes stale.
- **In the widget:** WidgetKit reloads the timelines by itself once an intent's `perform()` returns. Anything else that
  writes from here must call `WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)`.
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

## Seeing it run

Snapper can only be seen on a real Home Screen, so run the app (`just run`) and add the widget from the gallery. There
are no snapshot tests of the widget yet. Inspect the store with:

```sh
UDID="$(just _sim-udid)"
cat "$(xcrun simctl get_app_container "$UDID" me.southp.buffersnap group.me.southp.buffersnap)/captures.json"
```

Driving SpringBoard with the AXe binary from `App/CLAUDE.md` takes different commands than driving the app. These are
what worked on the iOS 27.2 simulator:

| To | Use |
|---|---|
| Tap a widget button or a menu item | `axe touch -x <x> -y <y> --down --up --delay 0.15 --udid "$UDID"` (`axe tap` didn't reliably register) |
| Enter edit mode | The same `axe touch`, with `--delay 2.0` on an empty spot |
| Change Home Screen page | `axe drag --start-x 360 --start-y 600 --end-x 40 --end-y 600 --udid "$UDID"` (`axe swipe` didn't page) |
| Leave the app without killing it | `xcrun simctl launch "$UDID" com.apple.Preferences`, then `xcrun simctl terminate "$UDID" com.apple.Preferences` (`axe button home` and a bottom-edge swipe didn't leave it). This lands on the first page |

When you check the count, make the expected value differ from what's on screen, and compare it with the store's count.
