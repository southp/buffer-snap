# App Review information

App Store Connect → the version page → **App Review Information**.

## Sign-in information

Tick **Sign-in required** and fill in the demo Buffer account. Never commit its real values here.

| Field | Value |
|---|---|
| User name | `<demo account email>` |
| Password | `<demo account password>` |

Before submitting, check the account on a phone that has never signed in to it:

- It signs in with the password alone: no two-factor authentication, and no step that needs its inbox. Checked on 2026-11-10 (#67): the password alone signed in, both in a browser and in the app.
- It has one organization, where the ideas land.
- It's on a Buffer plan that has Ideas and API access.

## Contact information

Your name, phone and email, which only Apple sees.

## Notes

Paste this into **Notes**. It's under the 4,000-character limit.

```
BufSnap sends ideas to a Buffer account. Capturing works without one, but sending needs one, so please use the demo account above.

The app opens on its list of captures. Ideas are captured from outside the app, by pressing a control or a widget, so there is no capture screen inside it.

FIRST LAUNCH
1. Open BufSnap. iOS asks for the microphone and then for speech recognition: please allow both. This comes first because iOS only lets an app ask while it's on screen. If either is refused, the top of the list says which, with Open Settings.

SIGNING IN
2. In the first row of the list, tap "Authenticate using your Buffer account". iOS asks to use "buffer.com" to sign in: tap Continue.
3. On Buffer's page, sign in with the demo account's email and password. No emailed link is needed.
4. Approve BufSnap's access. The app returns to the list. If ideas were waiting from before you signed in, it asks "Send N ideas to this account?": tap Send.

DICTATING WITHOUT OPENING THE APP
5. Add the "Dictate an Idea" control, in any of these places:
   - Control Center: swipe down from the top-right corner, tap + at the top left, tap "Add a Control", and search for "Dictate an Idea".
   - Action button (iPhone 15 Pro and later): Settings → Action Button → Controls → Choose a Control → "Dictate an Idea".
   - Lock Screen: touch and hold the Lock Screen → Customize → Lock Screen, remove a bottom button, tap +, and choose "Dictate an Idea".
   Or add a widget: touch and hold the Home Screen → Edit → Add Widget → BufSnap → "Dictate an Idea".
   The app shows these steps too, with a sketch of each: account menu (person icon) → "How to Add Dictate an Idea", or "Show Me How" on the empty list.
6. Press the control or the widget and speak. The app stays closed: a Live Activity shows the words on the Lock Screen and in the Dynamic Island. It stops when you press again, tap Stop, pause for 3 seconds, or after 60 seconds, then shows "Saved".

SEEING IT REACH BUFFER
7. Open BufSnap to see the idea in the list. Captures made within 5 minutes of each other are combined into one Buffer idea and sent once 5 minutes have passed since the last one. Tap "Send now" to send at once. The batching window is under the account menu (person icon) → Batching.
8. Sign in to https://buffer.com with the same account to see the ideas under Create → Ideas.

HELP
The account menu (person icon) also has Report a Problem, which opens the support page in Safari, Source Code on GitHub, and the app's version.

BACKGROUND MODES
- audio: BufSnap uses the audio background mode only while dictating an idea. Dictation starts only when the user presses the "Dictate an Idea" control or widget, shows a Live Activity with the words being heard and a Stop button for as long as it listens, and stops after 3 seconds of silence or 60 seconds at most. No audio is recorded or kept: speech goes straight to Apple's speech recognition, and only the text is saved.
- fetch (background app refresh): used only to send ideas to Buffer when a batch's 5-minute window ends while the app is closed.

PRIVACY
BufSnap has no server, analytics or third-party SDKs. It talks only to Buffer's API (OAuth with PKCE; tokens in the Keychain) and uses Apple's speech recognition.
```

## Attachment

None needed. If Review asks to see dictation from the control, record a screen video on an iPhone (Control Center →
Screen Recording, with the microphone on) and attach it to the reply.
