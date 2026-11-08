# App Store listing

What to paste into App Store Connect → the app → **App Information** and the version's **App Store** page. Each block
is ready to paste as is. Lengths are counted against Apple's limits.

## Name (App Information, ≤30)

```
BufferSnap
```

> [!WARNING]
> **Decide before submitting:** "Buffer" is Buffer's trademark. App Review can reject a name that uses another
> company's mark without permission (guideline 5.2.1), and many API terms forbid it. Keep it if Buffer has said yes,
> which Buffer Commit may count as. Otherwise, a name of your own avoids the question, e.g. `Snap Ideas` or
> `IdeaSnap`, with Buffer in the subtitle ("for Buffer" describes compatibility, which is usually allowed).

## Subtitle (App Information, ≤30)

```
Hands-free ideas for Buffer
```

27 characters. Alternatives: `Speak an idea into Buffer` (25), `Say it, and it's in Buffer` (26).

## Promotional text (version page, ≤170, can change without a review)

```
Press once, say the idea, and it's in Buffer. BufferSnap turns your voice into Buffer ideas from Control Center, the Action button or a widget, without opening the app.
```

168 characters.

## Description (version page, ≤4000)

```
Ideas don't wait for you to sit down. They show up mid-workout, on a walk, with your hands full. BufferSnap gets them into Buffer before they're gone: press once, say the idea, done.

PRESS, SPEAK, DONE
Add "Dictate an Idea" to Control Center, the Action button or the Lock Screen, or put the Dictate widget on your Home Screen. Press it and start talking. The app stays closed: your words show up live on the Lock Screen and in the Dynamic Island, and BufferSnap saves them when you press again, tap Stop or pause for 3 seconds.

STRAIGHT TO BUFFER
Every idea goes to the Ideas in your Buffer account, ready to turn into a post. Ideas you capture a few minutes apart are combined into one, so a train of thought stays together. You choose how long that window is, or turn it off.

WORKS OFFLINE
No signal? Captures are kept on your iPhone and sent when you're back online. Anything that couldn't be sent waits in the app, where you can send it again or delete it.

IN THE APP TOO
Hold the mic to dictate, or type when you can't speak aloud. The list shows everything you've captured and whether it has reached Buffer yet.

PRIVATE BY DESIGN
No account of ours, no servers, no analytics, no ads, no tracking. BufferSnap talks only to Buffer, and speech is recognized by Apple. Audio is never recorded or kept.

BufferSnap needs a Buffer account. It isn't made by Buffer.
```

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
| Version | `1.0.0`, the version the build carries |
| What's New | Not shown for a first version |
| Content Rights | No third-party content |
| Primary language | English (U.S.) |
