---
date: 2026-11-05
issue: 45
status: accepted
---

# Ask for the background wake-up when the open batch is due

**Decision:** When the app goes to the background with a batch open, it asks iOS for the wake-up at that batch's time, in place of the 15 minutes `44-background-sending.md` asks for. With nothing open it still asks for 15 minutes. The rest of that decision stands, and leaving the screen doesn't send an open batch.

**Why:** Before batching, what was still pending when the app left the screen was the exception. Now it's the usual case: save an idea, lock the phone, and the batch has its whole window to go. Asking for 15 minutes would be too late for the default 5 minutes, and for a 15-minute window it could come just before the batch is due and be wasted. Sending as the app leaves the screen would break the point of the window, as people often come back with the next thought.

**What this can't promise:** iOS decides. An earliest date is only ever a lower bound, so a batch may wait hours, or until the app next opens, as `10-capture-batching.md` already accepts. Someone who wants it gone at once has "Send now" or the off setting. None of this can run on a simulator.
