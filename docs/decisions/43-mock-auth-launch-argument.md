---
date: 2026-11-05
issue: 43
status: accepted
---

# Keep a way past sign-in on the simulator

**Decision:** In Debug builds only, launching with `-mockAuth signedOut` or `-mockAuth signedIn` runs `MockAuthService` instead of Buffer OAuth, for example `xcrun simctl launch "$(just _sim-udid)" me.southp.buffersnap -mockAuth signedIn`. Release builds don't contain this code.

**Why:** Agents drive the running app on the simulator and have no Buffer account to sign in with, so real OAuth would otherwise wall off every screen behind sign-in, including from the screenshots PRs need. Rejected: any switch a Release build could read, since a release must never skip real sign-in.
