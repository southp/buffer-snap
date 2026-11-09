---
date: 2026-11-09
issue: 68
status: accepted
---

# A session Buffer ended shows in the list, with ideas waiting

**Decision:** When Buffer ends the session, `checkSession()` and the queue's `sessionLost` move the app to signed out in place: the screen doesn't change, the waiting ideas stay waiting, and the list's row says Buffer ended the session and to authenticate again. Never having signed in isn't a lost session: the queue waits quietly, with no event and no call to Buffer.

**Why:** A session can end at any moment now that sends find out as well as the foreground check, as #60 found, and an idea someone is saying shouldn't be interrupted to take them to another screen. Signing in again goes through the same question as any other sign-in (`68-ideas-at-sign-in.md`).

After a relaunch the row shows plain offline mode instead: the session is gone from the Keychain, and it still says what to do. Rejected: remembering that a session ended, which is extra state for one sentence.
