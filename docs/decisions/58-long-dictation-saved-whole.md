---
date: 2026-11-08
issue: 58
status: accepted
---

# Save a long dictation from outside the app whole

**Decision:** A dictation started from the control or the widget is saved whole, even over the capture screen's 300-character limit. The Live Activity shows every word as it's heard, and the 60-second limit keeps it to about 150 words.

**Why:** `42-over-limit-dictation.md` leaves over-limit words in the text box to shorten, but outside the app there's no text box, and keeping them somewhere for later would need the app opened, which this path exists to avoid. Cutting them off loses words without saying so (`40-soft-character-limit.md`), and dropping the capture loses all of them. The person saw every word go by, so nothing is saved without their knowing.

Rejected:

- **Stopping at 300 characters:** it would cut a sentence mid-word, with the person still talking.
- **Saying "Too long" and saving nothing:** the idea is gone, and saying it again shorter is what this path is meant to spare.
