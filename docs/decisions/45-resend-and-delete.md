---
date: 2026-11-05
issue: 45
status: accepted
---

# Resend works on a whole batch, and delete on one capture

**Decision:** A failed batch has one Resend, on the batch. It makes every capture in it pending, and they go together as one idea, at once, with no window. Delete stays per capture, whatever state the batch is in: the rest of an unsent batch go without it, and deleting from a sent batch only removes the line from the list. "Send now" closes what's open, and from then on it goes like any closed batch.

**Why:** A batch fails as a whole, because it's one `createIdea`, so nothing about a single capture could be done differently by resending it alone. A resent batch is already closed, so it can't take in anything saved since it failed, and two batches can't merge just because both failed: each capture ends up in exactly one idea. A batch held before a sign-in closes too, for the same reason, so Resend brings back what was held and nothing else.

"Send now" writes the closed batch rather than setting a flag for the planner. The tap then survives being offline, a rate limit and a force-quit, and a capture saved a moment later starts the next batch even if nothing has left yet.

Deleting a capture can move when an open batch goes, as its time comes from the last capture and a gap might open up where it was. The list asks the queue to plan again after a delete, so that happens at once. Rejected: deleting the whole batch as one, which the issue rules out, and a Resend per capture, which would have to split a batch that was only ever one idea.

**A way out:** if Buffer refuses a batch for good, for example because of its length (`45-joined-batch-length.md`), Resend won't help. Deleting the captures that don't belong and resending what's left will, and nothing leaves the list by itself in the meantime.
