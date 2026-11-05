---
date: 2026-11-05
issue: 43
status: accepted
---

# Read the saved session before the first frame

**Decision:** `AppModel.init` asks `AuthService.hasSavedSession()`, a synchronous call, and starts on `.capture` or `.signedOut` straight away. It doesn't check with Buffer: `checkSession()` does that later, when the scene becomes active.

**Why:** A signed-in user never sees the sign-in screen flash, and #41's cold launch can call `showCapture()` the moment the model exists: `showCapture()` ignores calls while signed out, so a route that arrived late would swallow it. Reading the Keychain blocks the main thread for milliseconds, once, during launch. Rejected: an async restore behind a new `.launching` route, which adds a blank first frame and a queue for whatever arrives during it. Also rejected: waiting for Buffer before choosing the route, as capturing has to work offline.
