# App Privacy answers

App Store Connect → the app → **App Privacy**. These match the app's privacy manifest (`App/PrivacyInfo.xcprivacy`) and
the [privacy policy](https://southp.github.io/buffer-snap/privacy/). Why each one:
[`47-privacy-manifest.md`](../decisions/47-privacy-manifest.md).

## Privacy Policy URL

```
https://southp.github.io/buffer-snap/privacy/
```

## Data collection

**"Do you or your third-party partners collect data from this app?"** → **Yes, we collect data from this app**

Why: the text of each capture leaves the iPhone for the user's Buffer account and stays there.

## Data types

Tick only this one:

| Category | Type | Tick? | Why |
|---|---|---|---|
| Contact Info | all | No | The app never asks for a name, email or phone. Buffer's sign-in page does, on Buffer's side |
| Health & Fitness | all | No | None |
| Financial Info | all | No | None |
| Location | all | No | None |
| Sensitive Info | | No | None |
| Contacts | | No | None |
| **User Content** | **Other User Content** | **Yes** | The text of captures, sent to Buffer as ideas |
| User Content | Audio Data | No | Audio goes only to Apple's speech recognition and is never kept or sent anywhere else. Apple's processing isn't the app's collection |
| User Content | Emails or Text Messages, Photos or Videos, Gameplay Content, Customer Support | No | None |
| Browsing History | | No | None |
| Search History | | No | None |
| Identifiers | User ID, Device ID | No | No IDs of the app's own. Buffer's tokens and organization ID only go back to Buffer |
| Purchases | | No | None |
| Usage Data | all | No | No analytics |
| Diagnostics | all | No | No crash reporting of the app's own. iOS's reports to Apple don't count |
| Surroundings, Body | | No | None |
| Other Data | | No | None |

## Other User Content

| Question | Answer | Why |
|---|---|---|
| Purposes | **App Functionality** only | Sending the idea to Buffer is the app's one job. Not Analytics, Product Personalization, Advertising or Other |
| Is it linked to the user's identity? | **Yes** | It's stored in the user's own Buffer account |
| Is it used for tracking? | **No** | Nothing is shared with advertisers or data brokers, and there's no tracking SDK |

## The result on the product page

- **Data Linked to You:** User Content
- **Data Used to Track You:** none

## If you'd rather answer "Data Not Collected"

That's arguable too: the app has no server, and the text goes only to a service the user signed in to themselves.
If you choose it, empty `NSPrivacyCollectedDataTypes` in `App/PrivacyInfo.xcprivacy` in the same build, so the two
agree. Declaring it, as above, is the safer side: App Review rejects for too little disclosure, never for too much.
