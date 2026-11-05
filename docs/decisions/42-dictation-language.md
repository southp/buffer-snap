---
date: 2026-11-05
issue: 42
status: accepted
---

# Listen in the iPhone's first language, with one recognizer per hold

**Decision:** Dictation asks `SFSpeechRecognizer` for `Locale.preferredLanguages.first` and keeps what it gets, such as `zh-Hant-TW` becoming `zh-TW`. There's no language setting. On-device recognition isn't forced, so iOS chooses. Mixed Chinese and English goes through the one recognizer.

**Why:** A recognizer [supports only one language](https://developer.apple.com/documentation/speech/sfspeechrecognizer), so mixed speech has to go through the Chinese one or the English one, and following the phone is the choice that needs no setup. `Locale.current` is the wrong source: this app only has English strings, so it reports English on a phone set to Chinese. `SFSpeechRecognizer` already maps a language with a script to the locale it supports, which we confirmed on macOS but not yet on an iPhone, so there's no mapping table of our own. Not forcing on-device follows Apple's note that [on-device requests aren't as accurate](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition).

Rejected: `SpeechAnalyzer`, which needs iOS 26 while the app targets iOS 18.

**Not yet tested:** All of this rests on the device test in #42, above all how well `zh-TW` hears English words. If it's poor, this changes.
