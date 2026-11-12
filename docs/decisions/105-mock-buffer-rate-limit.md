---
date: 2026-11-12
issue: 105
status: accepted
---

# A mocked Buffer can rate limit the first send

**Decision:** Next to `-mockBuffer rejectFirst` (`44-mock-buffer-launch-argument.md`), `-mockBuffer rateLimitFirst`
makes the first send get a rate limit with a 2-minute `Retry-After`, which shows "Buffer asked BufSnap to wait" in the
list, for example `xcrun simctl launch "$(just _sim-udid)" me.southp.buffersnap -mockAuth signedIn -mockBuffer
rateLimitFirst`. Like the rest of the mock, it's only in Debug builds.

**Why:** Buffer's real rate limit can't be triggered on demand, and a reviewer should be able to see the state in the
running app without one. Two minutes is long enough to look at, and short enough to watch the wait end.
