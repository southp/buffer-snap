# Release notes

What each version of BufSnap brought, newest first, and what's next. Every version has a
[milestone](https://github.com/southp/buffer-snap/milestones) holding all of its issues.

| Version | Milestone | Status |
|---|---|---|
| 1.1.1 | [Smoother](https://github.com/southp/buffer-snap/milestone/5) | 🚧 Done and ready to submit to the App Store ([#134](https://github.com/southp/buffer-snap/issues/134)) |
| 1.1 | [Polishing](https://github.com/southp/buffer-snap/milestone/4) | ✅ Live on Nov. 17, 2026 |
| 1.0 | [v1](https://github.com/southp/buffer-snap/milestone/3) | ✅ Live on Nov. 11, 2026, and entered in Buffer Commit the same day |

## What's next

- Capturing multiple pictures in one camera session. Buffer's API needs public URLs for images, so this depends on a
  hosting decision.
- The [open issues](https://github.com/southp/buffer-snap/issues).

## 1.1.1, Smoother

Smoother signing in, and knowing who you're signed in as.

- **Smoother signing in** when Buffer emails a magic link instead of asking for a password
  ([#56](https://github.com/southp/buffer-snap/issues/56)).
- **See which Buffer account is signed in:** its name and initials ([#92](https://github.com/southp/buffer-snap/issues/92)),
  then its profile picture on the toolbar chip ([#108](https://github.com/southp/buffer-snap/issues/108)).
- **Light, Dark or System appearance,** chosen from the account menu ([#144](https://github.com/southp/buffer-snap/issues/144)).
- **Animated sketches** in the guide to adding Dictate an Idea ([#109](https://github.com/southp/buffer-snap/issues/109)).
- Small fixes: stale problems, going offline at launch, and the account chip's shadow
  ([#106](https://github.com/southp/buffer-snap/issues/106), [#150](https://github.com/southp/buffer-snap/issues/150)).

## 1.1, Polishing

Fixes and guides from the first users' reports, submitted before Buffer Commit's judging (Nov. 16-20).

- **A guide to adding Dictate an Idea** to Control Center, the Action button and the Lock Screen
  ([#98](https://github.com/southp/buffer-snap/issues/98)).
- **Say when the microphone is off** when you press Dictate an Idea ([#99](https://github.com/southp/buffer-snap/issues/99)).
- **Say when Buffer asks BufSnap to wait,** instead of flickering "Syncing" ([#105](https://github.com/southp/buffer-snap/issues/105)).
- **A BufSnap icon on the control,** based on the Doodle Bulb ([#103](https://github.com/southp/buffer-snap/issues/103)).
- **A link back to this repo** to report a problem, and to say it's open source ([#95](https://github.com/southp/buffer-snap/issues/95)).
- Restyled support and privacy pages ([#101](https://github.com/southp/buffer-snap/issues/101)), and layout fixes
  ([#97](https://github.com/southp/buffer-snap/issues/97), [#127](https://github.com/southp/buffer-snap/issues/127),
  [#129](https://github.com/southp/buffer-snap/issues/129)).

## 1.0

The first public release, made for [Buffer Commit](https://buffer.com/api/commit), whose entries were due by Nov. 13,
11:59 PM PT.

- Dictate an idea without opening the app, from the Action button, Control Center, the Lock Screen or the Home Screen
  widget.
- Sign in with Buffer, or capture offline until you do.
- Captures close together are batched into one Buffer Create idea, and sent in the background with retries.

### How it got there

The plan before 1.0, with the dates it aimed for:

1. ✅ [Scaffolding](https://github.com/southp/buffer-snap/milestone/1) (~ Nov. 1): the dev workflow is established,
   every component of the app is connected together, and the app runs on an iPhone through TestFlight. Everything
   could be mocked: what mattered was that the whole app flow ran end to end and the code base's architecture was
   settled.
2. ✅ [MVP](https://github.com/southp/buffer-snap/milestone/2) (~ Nov. 9): authentication, capturing by dictated text,
   batching, offline storage and the submission job all work.
3. ✅ [v1](https://github.com/southp/buffer-snap/milestone/3) (~ Nov. 10): submitted to the App Store early enough
   that a rejection still left time, then to Buffer Commit no matter what by Nov. 13. Everything to paste into App
   Store Connect, and the steps in order: [`docs/app-store/`](app-store/checklist.md).
