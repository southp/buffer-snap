---
date: 2026-11-08
issue: 46
status: accepted
---

# The in-memory fallback stays a log line

**Decision:** If the App Group container can't be opened, `BufferSnapApp` still logs an error and runs on
`InMemoryCaptureStore`, as `4-in-memory-fallback.md` decided. The app doesn't show it to the user. This replaces that
decision's plan to show it with the MVP.

**Why:** `containerURL(forSecurityApplicationGroupIdentifier:)` only fails when the build lacks the App Group
entitlement. That's a broken build, not something that happens on someone's phone: every build we ship is signed by
`just deploy` with `App/BufferSnap.entitlements`, and a build without it would show at once on a phone, as the widget's
count would never move. Nothing a user could do would fix it, so a message would only ever show in a build
we'd have to replace anyway. The unit-test host also launches the app, and the fallback keeps it from crashing there.
