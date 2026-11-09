---
date: 2026-11-09
issue: 68
status: superseded
superseded_by: 77-capture-only-from-outside-the-app.md
---

# The list is the first screen, and signing in is a row on it

**Decision:** `AppModel.route` is only `.captureList` or `.capture`, the list starts first signed in or not, and the capture screen is pushed on it. Signed out, the list opens with a persistent row that says "Offline mode", that everything is stored locally on this iPhone, and that ideas are only submitted to Buffer once the person authenticates their Buffer account, with the authenticate button right there. Signing in or out doesn't change the route.

The list hides everything that assumes an account while signed out: "Sends at…", Send now, Sync now and Resend. Each waiting batch says "Stored on this iPhone".

**Why:** Keeping an idea needs no account: only sending to Buffer does. So signing in is an action from the list, and the first press after installing already keeps an idea. Being plain about offline mode is a requirement from the owner, so nobody wonders whether an idea has gone anywhere.

Typing an idea stays reachable from the Account menu, as the capture screen is on its way out: capture happens outside the app (`58-dictate-outside-app.md`). The first-screen row isn't a separate screen to get past, which was the rejected alternative: a sign-in screen at launch that can be skipped, which is one more thing between an install and the first idea.
