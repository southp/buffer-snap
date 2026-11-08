---
date: 2026-11-08
issue: 58
status: accepted
---

# A press only starts a dictation from idle

**Decision:** A press of the control or the widget starts a dictation only when none is going and no outcome is on screen. While one is starting, it stops it as soon as the mic is on. While listening, it stops it. While finishing or saving, and for the 3 seconds an outcome shows, it does nothing. All of this lives in one `HandsFreeDictationSession` per app process, never in an intent.

**Why:** On the #57 spike, a second Action button press started another dictation instead of stopping. The spike toggled on "is a run going", which leaves several ways for a press meant to stop to start instead:

- **It lands just after silence stopped the dictation.** Silence stops after 3 seconds, about when someone reaches for the button again. Ignoring presses while the outcome shows covers this.
- **It lands while finishing**, waiting up to 5 seconds for the last words. Ignored.
- **It lands while starting**, before the mic is on. Remembered, and it stops once the mic is on.
- **A new intent instance per press.** Nothing lives in the intent, so it can't matter.

The device can't tell which one the spike hit, so the rules close all of them, and `HandsFreeDictationTests` checks each.

Rejected:

- **A cooldown by time alone:** it would also swallow a real second press while listening.
- **Treating a press after the outcome as a stop too:** nothing is running to stop, and someone with a second idea would have to press twice.
