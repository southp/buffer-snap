---
date: 2026-11-05
issue: 41
status: accepted
---

# Remove the widget's mock captures by their exact text

**Decision:** At launch, the app deletes each capture whose whole text is what the widget's mock buttons wrote for its kind: "Mock text capture" or "Mock photo capture". `captures-v2.json` keeps its name. A real text capture of exactly "Mock text capture" would go too, and nobody is likely to write that.

**Why:** Unlike the file #40 replaced (`40-new-capture-file.md`), this one can hold real ideas: #40 added the capture screen and every merge reaches TestFlight. Bumping the file name would delete those without a word, and they haven't been sent anywhere yet. #40 rejected filtering on text as a guess that could drop a real capture. Matching the kind and the whole text, not a "Mock …" prefix, leaves only someone typing those exact words.

Rejected:

- **Bumping the file name:** the smallest change, but it loses real captures.
- **Moving the real captures to a new file:** more code for the same result, and a widget that ran first would read an empty file.
- **A one-time flag:** more state. Nothing writes mocks any more, so running again finds nothing and writes nothing.

The check can go once no installed build predates #41. Until then it costs one read of the file per launch.
