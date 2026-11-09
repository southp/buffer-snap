---
date: 2026-11-05
issue: 41
status: superseded
superseded_by: 68-sign-in-from-the-list.md
---

# Don't remember a request for the capture screen made before sign-in

**Decision:** `AppModel.showCapture()` only moves from the capture list to the capture screen. Anywhere else it does nothing, and it stores nothing.

**Why:** Every way past sign-in already ends on the capture screen, and no route is saved between launches. So a cold launch reaches capture whichever comes first: the intent, or restoring the session or signing in. A pending request would add state with nothing to change. The route was also checked the other way round (anything but signed out moved to capture), which would have let the intent skip any new route that comes before sign-in finishes, such as one for restoring the session.

This stops being true if a later route leaves sign-in for another screen. That change has to apply the request itself.
