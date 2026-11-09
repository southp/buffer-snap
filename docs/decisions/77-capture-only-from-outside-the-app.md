---
date: 2026-11-09
issue: 77
status: accepted
---

# Capture only from outside the app, and the list is the only screen

**Decision:** The app no longer captures. The capture screen, its mic button, its text box and "Type an Idea" are gone, along with `CaptureModel` and `AppModel.route`. The app opens on the list, signed in or not, and Batching is the only thing pushed on it. `OpenCaptureIntent`, the "Capture an Idea" control and `buffersnap://capture` are gone too, and so is `AppLink`, which had no other link. The `buffersnap` scheme stays registered, because sign-in returns through it.

The storage format doesn't change: a capture of kind `.text`, typed or dictated, still loads, lists and sends. The rest of `68-sign-in-from-the-list.md` stands: signing in is a row on the list.

**Why:** BufSnap is meant to be used without opening it. Someone who has to open an app to type can open Buffer and type there, and a second way to capture is more to explain, review and keep working before the App Store deadline.

**What follows from it:**

- A "Capture an Idea" control someone placed goes away, as its kind no longer exists. "Dictate an Idea" is there to add instead. The `SnapperWidget`'s kind stays, so placed widgets stay.
- There's no draft, so signing out has nothing to discard, and `44-draft-survives-session-end.md` no longer applies.
- There's no text box, so `40-no-keyboard-on-open.md`, `40-soft-character-limit.md` and `42-over-limit-dictation.md` no longer apply. Dictating outside the app never had a limit (`58-long-dictation-saved-whole.md`).
- Dictating outside the app is the transcriber's only user, so it always mixes with other audio, and its `mixesWithOthers` and `Options` are gone. The language rule in `42-dictation-language.md` is unchanged.
