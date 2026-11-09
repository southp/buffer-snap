---
date: 2026-11-09
issue: 68
status: accepted
---

# Batches close by the same clock while signed out

**Decision:** The queue keeps closing batches whose window has ended while nobody is signed in, so each becomes one idea after sign-in, exactly as if it had been signed in all along. It asks Buffer nothing, and waits for the next window end the same way.

**Why:** Batches are worked out from timestamps and the current window, so the grouping doesn't need an account. Closing them as they end means a later change to the window setting can't regroup what was already captured, which is what closes it for someone signed in (`45-changing-the-window.md`).

Rejected: leaving everything open until sign-in, which would let a window changed in the meantime merge or split ideas after the fact.
