---
date: 2026-11-08
issue: 46
status: accepted
---

# The widget counts what's waiting to send

**Decision:** The Snapper widget shows how many captures are waiting to send, "3 waiting to send", or "Nothing waiting"
once there are none. It counts the same captures as the list's sync status (`SyncStatus.waitingCount(of:)`): pending
ones that can become an idea. Failed ones aren't counted, as they don't go by themselves.

**Why:** "12 captured" grew forever and said nothing about whether ideas had reached Buffer, which is the one thing worth
a glance now that capture happens outside the app. Counting failed ones as waiting would say they're on their way when
they need a tap, and saying "All sent" at zero would be wrong while any have failed, so zero says only that nothing is
waiting. The list says what failed and why. The widget has no way to know the queue is offline, as the queue lives in
the app's process, so it doesn't try.
