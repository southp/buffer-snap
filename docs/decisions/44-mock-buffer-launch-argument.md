---
date: 2026-11-05
issue: 44
status: accepted
---

# A mocked sign-in gets a mocked Buffer

**Decision:** In Debug builds, `-mockAuth` also swaps in `MockBufferClient`, so a mocked run never reaches Buffer's API. Adding `-mockBuffer rejectFirst` makes the first send fail, which shows the failed state and Resend, for example `xcrun simctl launch "$(just _sim-udid)" me.southp.buffersnap -mockAuth signedIn -mockBuffer rejectFirst`. Release builds don't contain this code.

**Why:** A mock token sent to the real API would only get a 401, and an agent's test text has no business going to Buffer's servers. Rejected: a separate switch for it, as nothing wants real Buffer with fake auth.
