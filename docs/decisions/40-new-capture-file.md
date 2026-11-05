---
date: 2026-11-05
issue: 40
status: accepted
---

# Start real captures in a new file and delete the mock one

**Decision:** Captures now live in `captures-v2.json`. The app deletes the old `captures.json` at launch and doesn't migrate it. The store's handling of an unreadable file doesn't change: reads and writes throw, and the file stays as it is.

**Why:** Builds before #40 could only write mock captures, as seeded samples or from the widget's buttons, so nothing in that file is worth keeping. A new name also covers both processes at once: the widget never reads the old file, even if it runs before the app's first launch after an update.

Rejected:

- **Skipping records that don't decode:** the mock `text` and `photo` captures decode fine, so they would still show.
- **Treating an unreadable file as empty:** same problem, and a future bug could then overwrite real captures.
- **Filtering by sample ids and "Mock …" text:** a guess that stays in the code, and could drop a real capture.
- **A one-time flag:** the widget can write before the app has set it, and that's more state for the same result.
