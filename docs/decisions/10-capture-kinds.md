---
date: 2026-11-05
issue: 10
status: accepted
---

# Ship text first, then multiple pictures, and drop video and voice

**Decision:** The first release captures text only. Multiple pictures come next: one camera session, with a thumbnail strip that grows with each shot. Video and voice recordings are dropped.

**Why:** Buffer Commit closes on Nov. 13. Pictures need more than a camera, because Buffer's API has no upload endpoint and takes [public, stable URLs](https://developers.buffer.com/guides/hosting-media.md) instead, so they depend on a hosting decision. Video is hard to control while capturing on the go, and dictation covers the need that voice recordings served.
