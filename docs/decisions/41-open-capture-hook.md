---
date: 2026-11-05
issue: 41
status: superseded
superseded_by: 77-capture-only-from-outside-the-app.md
---

# Reach the app from the intent through a hook the app sets

**Decision:** `OpenCaptureIntent` has one `perform()`, compiled into both targets, that calls a main-actor static closure, `onRun`. `BufferSnapApp.init` sets it to `AppModel.showCapture()`. In the widget's process nothing sets it, so `perform()` does nothing there.

**Why:** Apple requires an `openAppWhenRun` intent in both targets, and only the app has an `AppModel` to navigate. A hook is one optional closure, and it can't fail if the system ever runs the intent in the widget. `perform()` and the hook share the main actor, so it can't run before the app's `init`, even on a cold launch.

Rejected:

- **`@Dependency` with `AppDependencyManager`:** Apple's own pattern, but reading an unregistered dependency crashes, and the widget would have nothing registered.
- **A separate `perform()` in each target:** two more files, and each target's intent could drift from the other's.
- **`#if` on a compilation flag:** a new build setting for the same result.
- **A custom URL scheme:** the app has to register and parse one, and any other app could open it.
