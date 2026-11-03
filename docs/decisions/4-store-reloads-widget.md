---
date: 2026-11-03
issue: 4
status: accepted
---

# The app reloads the widget by wrapping its store

**Decision:** The composition root wraps the app's store in `NotifyingCaptureStore`, a Core decorator that calls a closure after each successful write. The closure, in the App layer, calls `WidgetCenter.shared.reloadTimelines(ofKind:)`.

**Why:** The widget's timeline never expires by itself, so a mutation that forgets to reload leaves a stale count. Wrapping the store covers every present and future mutation at one place, and Core can test it without WidgetKit. We rejected calling `reloadTimelines` from `CaptureListScreen` after each action: every new mutation would have to remember it, and no test could catch one that forgot.
