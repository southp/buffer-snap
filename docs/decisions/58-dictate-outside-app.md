---
date: 2026-11-08
issue: 58
status: superseded
superseded_by: 68-dictate-while-signed-out.md
---

# Dictate from a control without opening the app

**Decision:** The main way to capture is a press, not the app. The "Dictate an Idea" control (Control Center, the Action button, the Lock Screen's bottom buttons) and a small Home Screen widget run `DictateIdeaIntent`, an `AudioRecordingIntent` and `LiveActivityIntent`. The system runs it in the app's process with the app closed. It listens with `AppleSpeechTranscriber(mixesWithOthers: true)`, shows the words in a Live Activity, and saves them as a text capture through the app's `NotifyingCaptureStore`, as the capture screen does. Typing stays in the app.

The rules (what starts, what stops, what's saved) are `HandsFreeDictation` in Core, a pure state machine with the time passed in. `HandsFreeDictationSession` is the one owner in the app's process that the intents call, and the App only adds ActivityKit and a background task behind `DictationDisplay` and `DictationKeepAlive`.

**Why:** It's the fewest touches between an idea and Buffer, and what sets the app apart from Buffer's own. The #57 spike ([results](https://github.com/southp/buffer-snap/issues/57#issuecomment-6715563614)) proved it on an iPhone:

| Question | On the iPhone |
|---|---|
| Does a control dictate with the app closed? | Yes. `AudioRecordingIntent` + `LiveActivityIntent` runs in the app's process, and the words showed live in the Dynamic Island |
| Which audio session works in the background? | `.playAndRecord` with `.mixWithOthers`. Plain `.record` fails with `!int` |
| Does Stop in the Live Activity need a passcode? | No |
| Can a control or widget show a text box? | No, from neither process. Typing stays in the app |
| A notification reply as a text box? | Works, but too unusual to build on |
| Bugs | A second Action button press started another dictation; after Stop, "Saved" showed with the timer still running |

Both bugs are fixed by the rules: see `58-press-while-busy.md`, and only a listening status shows a timer, which the Live Activity draws only then.

Stops: a second press, Stop in the Live Activity, 3 seconds without new words once something's been heard, or 60 seconds. The outcome ("Saved", "Nothing heard", or what to open the app for) shows for 3 seconds, then the activity ends with `.immediate`. Ending at once with a delayed dismissal would be more robust to a suspended process, but the Dynamic Island drops an ended activity, so an unlocked phone would never see the outcome. A background task keeps the process alive for those seconds instead, and the app ends any activity a stopped process left behind at its next launch.

A saved dictation goes into the same queue as any capture. Right after saving, still in the background, the app sends it if its batch is due, or else asks iOS to wake it when the batch ends (`45-background-wake-at-window-end.md`), since the app may never come to the foreground.

Signed out, it says "Open BufferSnap to sign in" and doesn't listen. Without the microphone or speech recognition it says to open the app, which asks on its next foreground if the permission was never asked for: an app in the background can't show the prompt. Without a Live Activity it doesn't listen at all (`69-no-live-activity-no-mic.md`).

Rejected:

- **Opening the capture screen (#41) as the main path:** one more screen, and the hold-to-dictate mic needs the app on screen anyway.
- **Logic in the intent:** each press may get a new intent, so state there is how a second press could start a second dictation.
- **Merging the spike:** it logged results as captures and held five throwaway experiments.

## App Review note

For #47's submission notes:

> BufferSnap uses the `audio` background mode only while dictating an idea. Dictation starts only when the user presses the "Dictate an Idea" control or widget, shows a Live Activity with the words being heard and a Stop button for as long as it listens, and stops after 3 seconds of silence or 60 seconds at most. No audio is recorded or kept: speech goes straight to Apple's speech recognition, and only the text is saved.
