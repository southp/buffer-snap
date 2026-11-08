---
date: 2026-11-08
issue: 46
status: accepted
---

# Keep at most 500 captures, dropping the oldest sent ones

**Decision:** The store keeps at most 500 captures (`CappedCaptureStore.defaultLimit`). The app wraps its store in
`CappedCaptureStore`, which, each time captures are saved as submitted, deletes the oldest submitted ones until there
are 500 or fewer. It never deletes a pending or failed one, so the store can grow past 500 while that many haven't
gone, and shrinks again once they have.

**Why:** The store is one JSON file that the app and the widget read whole on every call, so it can't grow forever. 500
is months of ideas at a few a day, and the file stays under about 250 KB even with every capture at the 300-character
limit, which reads in milliseconds. A sent capture is already in Buffer, so dropping it only shortens the list's history. An unsent one exists
nowhere else, and losing an idea is the one thing this app mustn't do, so the limit gives way instead.

It runs right after a send is saved because that's the only moment a capture can become droppable. It's a wrapper
around the store, like `NotifyingCaptureStore`, so the queue doesn't need to know. A failed trim is logged and tried
again after the next send, since nothing is lost by keeping a few extra, and the send itself still counts as saved.

Rejected: a time limit, such as 30 days, which would empty the list for someone who captures rarely; and asking before
deleting, which is a question about ideas that are already safe in Buffer.
