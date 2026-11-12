---
date: 2026-11-12
issue: 99
status: accepted
---

# Say in the app when the microphone or speech recognition is off

**Decision:** Opening the app still asks for whatever is undecided, as
[`77-ask-for-permissions-at-launch.md`](77-ask-for-permissions-at-launch.md) set up. This replaces how 77 handled
someone who refused:

- **A press with a permission that isn't granted opens the app** on iOS 26 and later, the way
  [`69-no-live-activity-no-mic.md`](69-no-live-activity-no-mic.md) does when Live Activities are off.
  `HandsFreeDictationSession.press()` returns `.needsTheApp(.permission(_:))`, `DictateIdeaIntent` calls
  `continueInForeground` for any `.needsTheApp`, and `AppModel.dictationNotice` shows an alert that names what's off
  and offers Open Settings. The Live Activity still shows "Can't listen yet" first, so a locked iPhone, and iOS 18 to
  25, still say something. An undecided permission opens the app with no alert, because coming to the foreground is
  what asks for it.
- **The list shows a permission row**, under the sign-in row and above the sync status, while either permission is
  refused or restricted, with Open Settings. `AppModel.speechPermission` is read again each time the app becomes
  active, after any asking, so the row goes once both are allowed.
- **Restricted gets no Open Settings**, in the alert or the row: its switch isn't the user's to turn, so the text says
  who can.

**Why:** Someone on Discord pressed Dictate an Idea with the microphone refused and saw nothing they noticed. The Live
Activity's "Can't listen yet" lasts 3 seconds and doesn't say which permission is off. 77 rejected a row in the list
only because of the App Store deadline. The alert says why at the moment of the press. The row keeps saying it after
the alert is dismissed, until it's fixed.

Rejected:

- **Asking again from the app:** iOS shows each prompt once. After a refusal, only Settings can change it.
- **Showing Live Activities being off in the row too:** the list would need ActivityKit, and the press already says so.
