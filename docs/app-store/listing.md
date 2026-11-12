# App Store listing

What to paste into App Store Connect → the app → **App Information** and the version's **App Store** page. Each block
is ready to paste as is. Lengths are counted against Apple's limits.

## Name (App Information, ≤30)

```
BufSnap
```

> [!WARNING]
> **Decided, with a known risk:** the name is close to Buffer's trademark, so App Review could still reject it under
> guideline 5.2.1. The owner accepts that (`docs/decisions/75-bufsnap-name.md`). The subtitle's "for Buffer" describes
> compatibility, which is usually allowed.

## Subtitle (App Information, ≤30)

```
Hands-free ideas for Buffer
```

27 characters. Alternatives: `Speak an idea into Buffer` (25), `Say it, and it's in Buffer` (26).

## Promotional text (version page, ≤170, can change without a review)

```
BufSnap is free, with no in-app purchases, and its code is open (MIT). Take a look, report a problem or suggest an idea: github.com/southp/buffer-snap
```

150 characters: the description's "Free and open source" section, so it shows before 1.1 ships (#95). The 1.0 text was
`Press once, say the idea, and it's in Buffer. BufSnap turns your voice into Buffer ideas from Control Center, the
Action button or a widget, without opening the app.` (165).

## Description (version page, ≤4000)

```
Ideas don't wait for you to sit down. They show up mid-workout, on a walk, with your hands full. BufSnap gets them into Buffer before they're gone: press once, say the idea, done.

PRESS, SPEAK, DONE
Add "Dictate an Idea" to Control Center, the Action button or the Lock Screen's bottom buttons, or put the Dictate widget on your Home Screen. Press it and start talking. The app stays closed: your words show up live on the Lock Screen and in the Dynamic Island, and BufSnap saves them when you press again, tap Stop or pause for 3 seconds.

STRAIGHT TO BUFFER
Every idea goes to the Ideas in your Buffer account, ready to turn into a post. Ideas you capture a few minutes apart are combined into one, so a train of thought stays together. You choose how long that window is, or turn it off.

WORKS OFFLINE
No signal? Captures are kept on your iPhone and sent when you're back online. Anything that couldn't be sent waits in the app, where you can send it again or delete it.

ONE LIST
Open the app to see everything you've captured and whether it has reached Buffer yet.

PRIVATE BY DESIGN
No account of ours, no servers, no analytics, no ads, no tracking. BufSnap talks only to Buffer, and speech is recognized by Apple. Audio is never recorded or kept.

FREE AND OPEN SOURCE
BufSnap is free, with no in-app purchases, and its code is open (MIT). Take a look, report a problem or suggest an idea: github.com/southp/buffer-snap

Capturing works without an account, and sending ideas to Buffer needs a Buffer account. BufSnap isn't made by Buffer.
```

1547 characters. The "Free and open source" section ships with 1.1, since the description belongs to a version.

## What's New in This Version (version page, ≤4000, from 1.1)

```
• Show Me How: a guide to adding Dictate an Idea to Control Center, the Action button, the Lock Screen or a widget, with a sketch of each step. It's on the empty list and in the account menu.
• If the microphone or speech recognition is off, the list says which one, with a button to Settings.
• When Buffer asks BufSnap to wait, the list says so and when it will try again, instead of showing a failure.
• A new bulb on the control and the widget. The widget is now just the bulb, so nothing gets cut off.
• The account menu adds Report a Problem, a link to the source code, and the app's version.
• Handwritten titles are no longer clipped, and the empty list no longer overlaps the notices above it.
```

For 1.1 (#107), from the Polishing milestone's closed issues. Write a new one for each version, about what users will
notice, not how it's built.

## Keywords (version page, ≤100, comma-separated, no spaces after commas)

```
dictate,voice,idea,capture,note,social media,content,creator,inspiration,speech,action button,memo
```

98 characters. Words in the name and subtitle are already indexed, so "Buffer" isn't repeated here, and Apple discourages
other companies' names in keywords.

## Category (App Information)

| | Suggestion | Why |
|---|---|---|
| Primary | **Productivity** | It's a capture tool, next to note and voice-memo apps |
| Secondary (optional) | Social Networking | Where Buffer's own app is, and where creators look. Leave it empty if unsure |

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL (App Information) | `https://southp.github.io/buffer-snap/privacy/` |
| Support URL (version page) | `https://southp.github.io/buffer-snap/support/` |
| Marketing URL (version page, optional) | `https://github.com/southp/buffer-snap` |

The support page goes live once this branch merges, as the privacy page did. Until then, the repo's issues page works:
`https://github.com/southp/buffer-snap/issues`.

## Other fields

| Field | Value |
|---|---|
| Copyright | `2026 <your name>` |
| Version | The version the build carries: `1.0.0` for the first version, `1.1` now |
| What's New | Not shown for a first version. From 1.1, see "What's New in This Version" above |
| Content Rights | No third-party content |
| Primary language | English (U.S.) |
