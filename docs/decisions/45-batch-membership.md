---
date: 2026-11-05
issue: 45
status: accepted
---

# Work out an open batch from timestamps, and store a batch once it closes

**Decision:** A pending capture with no `batchID` is still open: which batch it's in is worked out from timestamps each time, with the current window. When a batch closes, each of its captures gets a `batchID` in one write, and from then on that alone decides the batch. A batch closes when it's about to be sent, on "Send now", or when it's held for a sign-in. The ID is its first capture's ID, and a capture that already has one keeps it.

**Why:** A batch has to stay the same once it may have reached Buffer, or a retry after a lost response could send different text. That needs something stored. Before that point, storing adds nothing: the window restarting, a relaunch mid-window, and changing the setting all follow from timestamps with no timer or record to keep up to date. There's also one place that writes the field, not every way of making a capture (the capture screen, #41's control and widgets, #42's dictation).

The ID comes from the capture, not from `UUID()`, so "Send now" and a window ending at the same moment close a batch to the same ID, and the list keeps showing the same row when a batch closes. `batchID` is optional, so files from before this decode as they are, and older builds ignore it. A submitted or failed capture with no `batchID` was made before batches existed, and counts as a batch of its own.

Rejected:

- **Only timestamps:** a capture saved just after a failed or sent batch would look like part of it, resending could merge batches that were sent apart, and changing the setting would rearrange what the list shows as already sent.
- **Storing the batch when saving:** every writer has to decide, it needs a separate "closed" marker anyway for captures saved mid-send, and a changed setting would have nothing to act on.
