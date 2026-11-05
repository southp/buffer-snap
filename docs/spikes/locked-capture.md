# Spike: what can capture on a locked iPhone?

Tested for [#10](https://github.com/southp/buffer-snap/issues/10) on 2026-11-04, on an iPhone 16 Pro with iOS 26.7.1. The throwaway code is on the `spike/locked-capture` branch.

## Bottom line

- **Text, photo and voice can all be captured without unlocking, but not from the same place.** Text and photo work in a Lock Screen capture extension. Voice works from a control.
- **Widgets can't capture while locked.** Their buttons ask for the passcode, even when the action is set to always allowed.
- **We chose not to build on this.** The app starts capture after unlock instead, and these results are kept for reference. See [the decision](../decisions/10-unlocked-capture.md).

## Matrix

✅ works locked · 🔓 needs unlock · ❌ doesn't work · ⬜ not tested

| Capture | Widget button (Lock Screen, Today View) | Control running an intent (Control Center) | Capture extension, opened by a control |
|---|---|---|---|
| **Text** | 🔓 Tested with a fixed action, which already stops at the passcode | ❌ No text box appears | ✅ Typing and dictation |
| **Photo** | ⬜ | ⬜ | ✅ |
| **Voice** | ⬜ | ✅ Starts locked. Stopping has limits, see below | ❌ `record()` returns `false` |
| **Video** | ⬜ | ⬜ | ⬜ |
| **Saving a fixed entry to the App Group store** | 🔓 | ✅ With `.alwaysAllowed` | ❌ No App Group access |

A ⬜ in the first two columns means there was no reason to try it: a widget can't host a camera, and a control has no screen of its own. Video was never tested in the extension either, and it's now [out of scope](../decisions/10-capture-kinds.md).

## What each surface did

### Widget buttons

The always-allowed action asked for the passcode on both the Lock Screen and the Today View. A Lock Screen button did run when the phone was already unlocked, so the buttons work and it's the lock that stops them.

### Controls

| Control | Result while locked |
|---|---|
| Default policy | 🔓 Asks for the passcode |
| `.alwaysAllowed` | ✅ Runs and writes to the App Group store |
| `$param.requestValue`, in the widget's process | ❌ No text box. Fails at once with `LNActionExecutorErrorDomain` 2010 |
| `$param.requestValue`, in the app's process | ❌ No text box. Fails at once with `NSCocoaErrorDomain` 4099 |
| Required `String` parameter | ❌ No text box, and `perform()` never runs |
| `openAppWhenRun` | 🔓 Asks for the passcode, then opens the app |

- **Lock Screen and Action button:** a control can be placed on both, but only the text prompt was tried there, and it showed no text box on either. Round 2 logged two attempts for three presses (Control Center, Lock Screen, Action button), so one press didn't reach the intent, and the log can't show which.
- **Other placements:** the camera and recording controls were only pressed in Control Center. Apple documents the extension launching from all three places.

### Capture extension

Opened from a control with no passcode prompt.

- **Text:** the text box, keyboard, typing and dictation all worked, on a phone set to Chinese.
- **Photo:** taken and imported.
- **Getting it to the app:** files stayed in the session folder after swiping away, with or without a photo. The app imported them the next time it ran, after unlock.
- **Microphone:** `AVAudioRecorder.record()` returned `false`. Other ways of recording weren't tried, such as a capture session with an audio input.

Apple's [restrictions](https://developer.apple.com/documentation/lockedcameracapture/creating-a-camera-experience-for-the-lock-screen): no network, no App Group, and the system ends the extension soon after launch unless a camera view is active. The spike's text box sat on top of a live viewfinder because of that last rule.

### Voice from a control

Recorded 10 seconds (140,526 bytes) with the log reading `LOCKED` throughout. Nobody listened to the file, so the size is the only evidence that it holds real audio. It took all of this:

- **The app's process:** add `LiveActivityIntent` to `AudioRecordingIntent`. Alone, `AudioRecordingIntent` ran in the widget's process, where the Live Activity failed with `unsupportedTarget` and the audio session with `!pla`.
- **A session that mixes:** `.playAndRecord` with `.mixWithOthers`. Plain `.record` failed to activate with `!int`, which [another developer also hit](https://developer.apple.com/forums/thread/836958).
- **App settings:** `UIBackgroundModes: audio` and `NSSupportsLiveActivities`.

**Stopping:** the Live Activity's Stop button asks for the passcode, even when always allowed. A timer in the app stopped the recording while locked. Pressing the control a second time wasn't tried. The tester saw the Live Activity end after 5–7 seconds, while the log shows 10 seconds of recording, and this wasn't explained.

**Hold to record, as the README first proposed, isn't possible:** a control is a single press.

### Siri

Not tested: the phone is set to Chinese, and Siri isn't planned.

## Text capture for MVP

1. Press the **BufferSnap control** on the Action button, in Control Center or on the Lock Screen. A widget button on the Today View, Home Screen or Lock Screen does the same.
2. Unlock if needed, usually just a glance with Face ID, and the app opens on the capture screen.
3. **Hold the mic, speak and release**, or use the keyboard if you can't speak aloud.
4. Leave the app. The capture joins [the current batch](../decisions/10-capture-batching.md), which is sent when the window ends.

| Step | Status |
|---|---|
| A control opens the app after unlock | ✅ Tested from Control Center |
| A Lock Screen widget button runs once unlocked | ✅ Tested |
| A button from the Today View once unlocked | ⬜ Not tested |
| Opening straight on the capture screen | ⬜ Not tested |
| Hold to dictate with the Speech framework, including mixed Chinese and English | ⬜ Not tested. Test this first: it's the main path |

## Implied targets

**No new target for MVP.**

| Target | What |
|---|---|
| `BufferSnapWidget` (existing) | The control and buttons, with an intent shared with the app that opens it |
| App (existing) | The capture screen, the Speech framework, and microphone and speech recognition permissions |

## If a capture extension comes back

The photo path needs no unlock and is what Apple built the extension for, so it could still return. Beyond what's listed in `project.yml`, it needs this:

- **Register its App ID first.** `just deploy` archives unsigned, so it doesn't register new IDs. The spike registered `me.southp.buffersnap.camera`.
- **Teach `just deploy` to sign it.** The extension is embedded in `Extensions/`, not `PlugIns/`, so the recipe's signing guard doesn't see it.
- **Don't give it the App Group.** It can't use it, and the App Store Connect API key can't assign one (401 on `xcbuild/v1/appGroups`).

XcodeGen's embed path for it also produces a warning that doesn't stop the build.

## How this was tested

The phone's biometrics were off during each round: holding the side and volume buttons, then tapping Cancel, makes the next unlock need the passcode. **With Face ID on, every 🔓 above is usually just a glance at the phone.**

Each action logged its time, process and lock state to the App Group. The lock state came from a `.completeFileProtection` file, which can't be read about 10 seconds after locking. The capture extension can't reach the App Group, so its lines show `NO-GROUP`; for those, the evidence is the tester seeing no passcode prompt, between `LOCKED` readings from other actions. Attempts that never reached `perform()` leave no log line, so those results are what the tester saw.
