# App Review information

App Store Connect → the version page → **App Review Information**.

## Sign-in information

Tick **Sign-in required** and fill in the demo Buffer account. Never commit its real values here.

| Field | Value |
|---|---|
| User name | `<demo account email>` |
| Password | `<demo account password>` |

Before submitting, check the account on a phone that has never signed in to it:

- It signs in with the password alone: no two-factor authentication, and no step that needs its inbox.
- It has one organization, where the ideas land.
- It's on a Buffer plan that has Ideas and API access.

## Contact information

Your name, phone and email, which only Apple sees.

## Notes

Paste this into **Notes**, and replace the two placeholders. It's under the 4,000-character limit.

```
BufferSnap sends ideas to the reviewer's Buffer account. It needs a Buffer account, so please use the demo account above.

SIGNING IN
1. Open BufferSnap and tap "Authenticate using your Buffer account". iOS asks to use "buffer.com" to sign in: tap Continue.
2. On Buffer's page, sign in with the demo account's email and password. Buffer may offer to email a sign-in link (a "magic link") instead; please choose the password option, as the demo account's inbox isn't available to you.
3. Approve BufferSnap's access. The app returns to its capture screen.

TRYING IT IN THE APP
4. Hold the large mic button and speak, then release. Allow the microphone and speech recognition when asked. The words appear in the text box and are saved. You can also type an idea and tap Save.
5. Tap the list button at the top right to see captures. Captures made within 5 minutes of each other are combined into one Buffer idea and sent once 5 minutes have passed since the last one. Tap "Send now" to send at once. The batching window is under the account menu (person icon) → Batching.
6. Sign in to https://buffer.com with the same account to see the ideas under Create → Ideas.

THE MAIN FEATURE: DICTATING WITHOUT OPENING THE APP
Step 4 must come first, because iOS only lets an app ask for the microphone while it's on screen.
7. Add the "Dictate an Idea" control, in any of these places:
   - Control Center: swipe down from the top-right corner, tap + at the top left, tap "Add a Control", and search for "Dictate an Idea".
   - Action button (iPhone 15 Pro and later): Settings → Action Button → Controls → Choose a Control → "Dictate an Idea".
   - Lock Screen: touch and hold the Lock Screen → Customize → Lock Screen, remove a bottom button, tap +, and choose "Dictate an Idea".
   Or add the widget: touch and hold the Home Screen → Edit → Add Widget → BufferSnap → "Dictate an Idea".
8. Press the control or the widget and speak. The app stays closed: a Live Activity shows the words on the Lock Screen and in the Dynamic Island. It stops when you press again, tap Stop, pause for 3 seconds, or after 60 seconds, then shows "Saved". The idea appears in the app's list and goes to Buffer as in step 5.

BACKGROUND MODES
- audio: BufferSnap uses the audio background mode only while dictating an idea. Dictation starts only when the user presses the "Dictate an Idea" control or widget, shows a Live Activity with the words being heard and a Stop button for as long as it listens, and stops after 3 seconds of silence or 60 seconds at most. No audio is recorded or kept: speech goes straight to Apple's speech recognition, and only the text is saved.
- fetch (background app refresh): used only to send ideas to Buffer when a batch's 5-minute window ends while the app is closed.

PRIVACY
BufferSnap has no server, analytics or third-party SDKs. It talks only to Buffer's API (OAuth with PKCE; tokens in the Keychain) and uses Apple's speech recognition.
```

## Attachment

None needed. If Review asks to see dictation from the control, record a screen video on an iPhone (Control Center →
Screen Recording, with the microphone on) and attach it to the reply.
