---
date: 2026-11-09
issue: 68
status: accepted
---

# Dictating outside the app listens and saves while signed out

**Decision:** The sign-in guard in `HandsFreeDictationSession` and the "Open BufferSnap to sign in" outcome are gone. A press listens and saves whether or not anyone is signed in. The rest of `58-dictate-outside-app.md` stands: the control, the Action button and the widget run `DictateIdeaIntent`, with the same stops and outcomes.

**Why:** The first press after installing should already keep an idea. Saving needs no account, and the queue waits quietly until someone signs in (`68-session-ended-in-the-list.md`). The microphone and speech recognition still need permission, so that outcome stays.
