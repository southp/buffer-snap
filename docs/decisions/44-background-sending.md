---
date: 2026-11-05
issue: 44
status: accepted
---

# Send from a background refresh, in the app's own process

**Decision:** `.backgroundTask(.appRefresh(...))` on the app's scene runs the same `SubmissionQueue`, in the app's process, on the one `AuthService`. A wake-up is requested each time the app goes to the background and each time one runs, for 15 minutes later at the earliest. The app also asks for extra time as it leaves the screen, to finish what it's sending. The settings are `UIBackgroundModes: fetch` and `BGTaskSchedulerPermittedIdentifiers` in `App/Info.plist`, as they have no `INFOPLIST_KEY_` setting. No new entitlement or App ID capability.

**Why:** Refresh tokens are single-use, so a second process refreshing would revoke the session. That rules out a widget or an extension sending. When a background task runs out of time it stops waiting, but the send carries on until iOS suspends the app, as cancelling a request Buffer may have acted on could only cause a duplicate. Asking for a wake-up even with nothing pending keeps this simple, and a wake-up with nothing to do makes no requests. Rejected: `BGProcessingTask`, which is meant for long jobs and only runs when iOS likes, and a background `URLSession`, which would need the request built ahead of time with a token that may have expired by the time it goes.

**What this can't promise:** iOS decides if and when a background refresh runs, based on things like how often the app gets used and battery state. It may be hours, and it never runs after force-quitting until the next launch. So a capture that's still pending goes when the app next opens at the latest. Extra time can run out too: iOS can then freeze a request mid-flight, and if its answer is lost, that's the duplicate `44-duplicate-ideas.md` accepts. A simulator can't run any of this: `BGTaskScheduler` refuses requests there. Only a real iPhone shows whether it works.
