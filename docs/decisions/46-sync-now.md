---
date: 2026-11-08
issue: 46
status: superseded
superseded_by: 105-say-when-buffer-asks-to-wait.md
---

# Sync now sends what's waiting, not what failed

**Decision:** The capture list starts with one sync status: everything's sent, N waiting (with when the open batch
goes), offline (sends once there's a connection), or N not sent (needs a tap on Resend). Sync now closes whatever is
open and runs the queue, like the open batch's Send now, and shows "Syncing…" until that pass ends. It doesn't resend
failed batches: those keep their own Resend.

"Offline" means the queue's last pass ended without reaching Buffer (`BufferError.connection`, or `AuthError.network`
while refreshing), which `SubmissionQueue.isOffline` keeps until a pass gets an answer. Any other reason to wait, such
as a back-off or a rate limit, shows as waiting: it still goes by itself.

**Why:** Capture now happens outside the app (`58-dictate-outside-app.md`), so opening the app is mostly to check that
everything reached Buffer. One line at the top answers that without reading every batch header.

Failed batches stay out of Sync now because each failure needs a person's choice: a held batch may be someone else's
(`44-hold-captures-at-sign-in.md`), and a refused one fails again unless some captures are deleted
(`46-say-why-a-batch-failed.md`). Sending them all with one tap would undo both.

Offline comes from the queue, not from `NWPathMonitor`, because what matters is whether Buffer could be reached. A
phone on Wi-Fi with no internet looks online to the path monitor, and nothing shows "offline" when there's nothing to
send. Rejected: a status per send attempt (sending, backing off, rate limited), which tells someone nothing they can act
on, as it all goes by itself.
