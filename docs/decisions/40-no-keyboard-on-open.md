---
date: 2026-11-05
issue: 40
status: superseded
superseded_by: 77-capture-only-from-outside-the-app.md
---

# Don't raise the keyboard when the capture screen opens

**Decision:** The text box waits for a tap, and the keyboard doesn't open by itself.

**Why:** The mic is the main path and the keyboard the backup (`10-text-capture.md`), and an open keyboard would cover the space the mic button takes in #42. Until #42 lands this costs typing one extra tap. Raising the keyboard now would save that tap for about a week, then have to come out.
