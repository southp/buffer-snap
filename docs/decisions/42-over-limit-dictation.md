---
date: 2026-11-05
issue: 42
status: accepted
---

# Leave dictation that can't save in the text box

**Decision:** Releasing the mic saves only when the words fit under the 300-character limit. Otherwise they stay in the box with a message, to shorten and save by hand. The same goes for anything that ends a hold without a release: an interruption such as a call, the app leaving the foreground, or the recognizer stopping while the mic is still held. Words are never cut off or saved without the person knowing.

**Why:** Speech reaches the limit quickly: about 25 seconds of English at 150 words a minute, and about a minute of Chinese. So this will happen, and `40-soft-character-limit.md` already rules out cutting text off. Saving when the recognizer stops mid-hold would miss whatever is said next, with the person still talking and no sign of it.

Rejected:

- **Splitting a long dictation into several captures:** batching (`10-capture-batching.md`) would join them again in Buffer, so it's a real option, but it cuts sentences at arbitrary points and needs its own rule for where. Worth revisiting if the device test shows editing long dictations is a chore.
- **Raising the limit for dictation:** that makes two limits to explain for the same capture.
- **Saving on interruption:** the release that would have asked for a save never came, and a half-finished thought shouldn't reach Buffer unseen.
