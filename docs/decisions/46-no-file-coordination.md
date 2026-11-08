---
date: 2026-11-08
issue: 46
status: accepted
---

# No cross-process coordination for the capture file

**Decision:** `JSONFileCaptureStore` keeps writing the whole file atomically, with no `NSFileCoordinator` or lock. Only
the app's process writes it, through the one `NotifyingCaptureStore` that `BufferSnapApp` builds, and an actor
serializes those writes. The widget only reads.

**Why:** A lost write needs two writers at once. Since #58 the intents that capture run in the app's process and write
through the app's store, and the widget extension writes nothing (`Widget/CLAUDE.md`), so there's only ever one writer.
Atomic writes already mean a reader never sees half a file. Coordination would add a blocking API to every read and
write to guard against a case that can't happen. If anything outside the app's process ever writes the file, this has
to be revisited first.
