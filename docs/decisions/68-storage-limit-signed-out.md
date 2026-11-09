---
date: 2026-11-09
issue: 68
status: accepted
---

# Signed out, the storage limit never drops an idea

**Decision:** `CappedCaptureStore` is unchanged. Signed out, nothing is ever submitted, so nothing ever trims: every capture stays, and the store can grow past 500 while it waits. Sending at sign-in trims only what's already in Buffer, after each send, and never an unsent capture.

**Why:** The cap only ever deletes submitted captures (`46-storage-limit.md`), and losing an idea is the one thing this app mustn't do, so at the limit the limit gives way.

**What it costs:** while signed out the file has no upper bound, and the app and widget read it whole on every call. A dictation is at most about 150 words (`58-long-dictation-saved-whole.md`), so roughly 1 KB, which makes a few thousand waiting captures a few MB. That's an estimate, not a measurement.

Rejected: warning at the limit or refusing new captures, which either tells someone about a limit that doesn't cost them anything or loses the idea the limit was meant to protect. A warning can come later if the file ever grows far enough to matter.
