---
date: 2026-11-05
issue: 10
status: accepted
---

# Batch captures made close together into one idea

**Decision:** Captures with less than 5 minutes between them become one Buffer Create idea, in the order they were made. The 5 minutes is a setting, and the window restarts after each capture. The batch is sent when the window ends, and "Send now" sends it early.

**Why:** Things captured in quick succession are usually about the same thought, which sets this apart from opening Buffer's own app. It has to wait because Buffer's public API reference has `createIdea` but no way to update an idea, so a batch can't grow once it's sent. iOS doesn't guarantee a background wake-up, so a batch may wait until the app next opens. Rejected: one idea per capture, which leaves the grouping to do by hand later.
