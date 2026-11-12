---
date: 2026-11-09
issue: 77
status: superseded
superseded_by: 99-say-when-a-permission-is-off.md
---

# Ask for the microphone and speech recognition when the app opens

**Decision:** Whenever the app comes to the foreground and either permission is still undecided, `HandsFreeDictationSession.askForPermissionIfNeeded()` asks for it. Once both are decided it does nothing, so someone who refused is never asked again. A press from outside the app still can't ask: it shows the Live Activity's "Can't listen yet", and only opening the app asks.

**Why:** The mic button was the only other place that asked, and it's gone, so the app has to ask without being pressed. With the question at launch, opening the app once is enough for the first press to dictate. The state comes from iOS each time, not from a remembered "first launch" flag, so it also covers someone who quit between the two prompts, and an update from a build that never asked.

The check runs with `initial: true`, because the scene is already active the first time it's read. On a fresh install in the simulator, without it, the prompts only came up once the app had left the foreground and returned. The prompts take the app out of the foreground, and answering the first one brings it back while the second is still to come. So the session ignores a call while it's already asking, or both prompts would be requested twice.

**Someone who refused:** the capture screen was also where the refusal was explained, with a button to Settings. There's no screen for that now, so the Live Activity's text adds "or turn them on in Settings", and the support page says the same. Rejected for now: a row in the list that says the permission is off, which is new UI this close to the App Store deadline.

**Tests and screenshots:** a test host and `just store-screenshots` launch with `-skipPermissionPrompt YES`, in Debug only, as nobody is there to answer. `simctl privacy` can grant the microphone but has no service for speech recognition, so it can't replace the argument.
