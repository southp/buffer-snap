---
date: 2026-11-05
issue: 44
status: superseded
superseded_by: 77-capture-only-from-outside-the-app.md
---

# Keep the draft in memory above the route

**Decision:** `BufferSnapApp` owns `CaptureModel` next to `AppModel` and hands it down, so routing to sign-in no longer destroys the draft. After signing back in, the capture screen still has it. Signing out on purpose discards it. It's kept in memory only, so quitting the app still loses a draft, as it always has.

**Why:** A session can end while someone is typing, now that sends find out as well as the foreground check, and they didn't choose that. The draft doesn't go anywhere by itself, because it takes a tap on Save, so it's safe even if a different account signs in next. Moving the model up is the option `40-route-drives-navigation-stack.md` already named. Rejected: saving the draft to disk, which is more than this needs and would need a rule for who it belongs to, and keeping the capture screen alive under a sign-in overlay, which leaves a live text field and its keyboard behind sign-in.
