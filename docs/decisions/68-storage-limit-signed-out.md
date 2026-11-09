---
date: 2026-11-09
issue: 68
status: accepted
---

# Signed out, the storage limit never drops an idea

**Decision:** `CappedCaptureStore` is unchanged. Signed out, nothing is ever submitted, so nothing ever trims: every capture stays, and the store can grow past 500 while it waits. Sending at sign-in trims only what's already in Buffer, after each send, and never an unsent capture.

**Why:** The cap only ever deletes submitted captures (`46-storage-limit.md`), and losing an idea is the one thing this app mustn't do, so at the limit the limit gives way. Nothing else needed changing: the file stays small even at a few thousand captures, as each is at most a few hundred characters.

Rejected: warning at the limit or refusing new captures, which either tells someone about a limit that doesn't cost them anything or loses the idea the limit was meant to protect. A signed-out warning can come later if the file ever grows far enough to matter.
