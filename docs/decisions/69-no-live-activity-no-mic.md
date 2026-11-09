---
date: 2026-11-09
issue: 69
status: accepted
---

# No Live Activity, no mic

**Decision:** If a press can't start a Live Activity, because Live Activities are off or iOS refused one, the microphone stays off and nothing is saved. On iOS 26 and later the intent brings the app forward with `continueInForeground`, and the app says why and offers Settings. `DictationDisplay.show` returns whether there's an activity, and `HandsFreeDictationSession.press()` returns `.needsTheApp` when a press had nowhere to show what happened.

**Why:** Dictating with Live Activities off crashed the app (#60, row D3). On an iPhone, the console said:

> AppIntents/PerformActionExecutorTask.swift:669: Fatal error: AudioRecordingIntent was performed with an active audio session but without a Live Activity

So the old expected result, "nothing shows, but it still saves", can't happen with `perform()` returning while the mic is on. The check needs an active audio session, so a press that never opens the mic is safe.

**What it costs:** Someone with Live Activities off can't dictate from outside the app until they turn them on. On iOS 18 to 25, `continueInForeground` doesn't exist, so the press doesn't crash but nothing says why at that moment. Its replacement there, `ForegroundContinuableIntent`, is unavailable in app extensions, and `DictateIdeaIntent` is compiled into the widget too.

Rejected:

- **Holding `perform()` open until the dictation ends, so no check sees an active session:** it leans on when an undocumented check runs. It would also listen with no words on screen and no Stop button, which isn't what the App Review notes promise.
- **A notification saying why:** the app doesn't ask for notification permission, and this one case isn't worth asking for it.
- **Saying so with `.result(dialog:)`:** a result's type is fixed, so every press would need a dialog.
