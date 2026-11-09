---
date: 2026-11-09
issue: 81
status: accepted
---

# Dictate an Idea is the only widget

**Decision:** `SnapperWidget` goes, in both its sizes (`systemMedium` and `accessoryCircular`). The extension keeps the "Dictate an Idea" widget (`DictateWidget`), the "Dictate an Idea" control and the Live Activity. The way to dictate from the Lock Screen is the control, in its bottom buttons.

Everything that existed only for `SnapperWidget` goes with it: `NotifyingCaptureStore` and the timeline reload on every store write, `SharedStorage.widgetKind`, and `SyncStatus.waitingCount(of:)`. `DictateWidget` shows nothing from the store, so it has no timeline to reload.

**Why:** On an iPhone the Lock Screen face only opened the app when tapped, even as `Button(intent: DictateIdeaIntent())`, the case `77-lock-screen-widget-dictates.md` left to be checked. With no capture screen, opening the app does nothing useful. The `systemMedium` face offered the same press as `DictateWidget`, so the gallery showed two near-identical widgets, and its count of what's waiting is what the list already says.

Rejected:

- **Moving the waiting count onto `DictateWidget`:** it would keep the reload on every write alive to repeat what the list says.
- **Keeping `SnapperWidget`'s kind so that placed widgets stay:** a placed one goes away with its kind, as the "Capture an Idea" control did (`77-capture-only-from-outside-the-app.md`). "Dictate an Idea" is there to add instead.

**Kept:**

- **The captures stay in the App Group container, in `captures-v2.json`,** so an update loses nothing. Now that only the app reads them, the extension's App Group entitlement isn't used, but it stays: removing it is a signing change that only a signed build on an iPhone can check, and it costs nothing.
- **`JSONFileCaptureStore` still reads the file on every call.** Nothing relies on that across processes any more, but changing it is a storage change this doesn't need.
- **`SnapperWidgetBundle` and the `BufferSnapWidget` target keep their names,** since a rename removes no code.
