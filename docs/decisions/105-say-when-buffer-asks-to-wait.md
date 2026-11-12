---
date: 2026-11-12
issue: 105
status: accepted
---

# The sync status says when Buffer asks BufSnap to wait

**Decision:** The capture list's sync status gets a fifth state, rate limited: "N waiting to send", then "Buffer asked
BufSnap to wait. Trying again in 2 min", with Sync now off until then. It shows while `SubmissionQueue.rateLimitedUntil`
is in the future and something is waiting, and it comes before a failure: nothing goes before the wait ends, a Resend
included, and each failed batch still says "Not sent" in its own header. The time left is in whole minutes or hours,
rounded up, so it never reads "0 min". Send now and Resend still take a tap during the wait: what they close or reopen
goes when it ends. Everything else in `46-sync-now.md` stands: Sync now sends what's waiting and leaves failed batches
to their own Resend, and offline means the last pass couldn't reach Buffer. This supersedes `46-sync-now.md`, which
showed a rate limit as plain waiting.

**Why:** While Buffer rate limits the queue, a pass can't start, so Sync now returned at once and "Syncing…" flashed
with nothing sent and nothing said (#105). A rate limit is the one wait a tap can't shorten, so it's the one worth
naming. `46-sync-now.md` rejected a status per send attempt, and a back-off still shows as waiting, as that one goes by
itself whenever Sync now is tapped.

The queue answers `rateLimitedUntil` with `nil` once the time has passed, and publishes `rateLimitChanged` when a wait
starts and when it ends, so the list follows it like `isOffline`. Rejected: an optional `until`, since a rate limit
always ends at a known time (`Retry-After`, or the back-off when Buffer gives none), and a clock read in the view to
count down, which would break snapshots (`3-injected-now.md`). The list redraws each minute, so "Trying again in" is
up to a minute behind, and rounding up keeps it from promising too soon.
