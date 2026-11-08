---
date: 2026-11-03
issue: 4
status: superseded
superseded_by: 46-in-memory-fallback-stays-silent.md
---

# The app falls back to the in-memory store if the shared store won't open

**Decision:** If the App Group container is unavailable or the seed can't be written, `BufferSnapApp` logs an error and runs on `InMemoryCaptureStore` with the same seed. Showing the error to the user comes with the MVP.

**Why:** A launch crash would leave the user with nothing, and it would also take down the unit-test host, which launches the app. We rejected a silent empty list too: the log line is what makes a missing entitlement diagnosable. The cost is that a misconfigured build still looks like it works until the widget's captures fail to appear.
