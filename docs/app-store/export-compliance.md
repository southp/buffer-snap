# Export compliance

**Nothing to fill in.** The app's `Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO` (`App/target.yml`), so App
Store Connect doesn't ask about encryption for any build, and none needs documents.

Checked on a Release build of this branch: `plutil -p BufferSnap.app/Info.plist` shows
`"ITSAppUsesNonExemptEncryption" => false`.

## Why `NO` is right

Every bit of encryption in the app is Apple's own, which is exempt:

| Where | What | Exempt because |
|---|---|---|
| Talking to Buffer | HTTPS through `URLSession` | Encryption built into iOS |
| Sign-in | SHA-256 of the PKCE verifier, with CryptoKit | Hashing, not encryption, and Apple's |
| Sign-in tokens | The iOS Keychain | Encryption built into iOS |

There's no third-party code, no encryption of its own, and no proprietary algorithm. No annual self-classification
report is due for this.

## If App Store Connect asks anyway

For example on the version page, under **App Encryption Documentation**:

| Question | Answer |
|---|---|
| Does your app use encryption? | Yes |
| Does your app qualify for any of the exemptions? | Yes: it only uses encryption within Apple's operating system |
| Does your app implement any encryption algorithms that are proprietary or not accepted as standard? | No |
| Is your app going to be available on the App Store in France? | Doesn't need a declaration, as above |
