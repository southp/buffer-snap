---
date: 2026-11-17
issue: 92
status: accepted
---

# Keep the account's name in its own Keychain item

**Decision:** `KeychainAccountStore` keeps the signed-in account's name and email, and when Buffer gave them, as a JSON generic-password item of its own (`me.southp.buffersnap.buffer-account`). It has the session's accessibility (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) and no access group, as in `43-keychain-session.md`. `AppModel` clears it on sign-out, when Buffer ends the session, and when a sign-in succeeds, before fetching the new account.

**Why:**

- **Not a field on `AuthSession`:** the session is decoded at every launch, and a decoding change there could sign everyone out. Here, the worst a bad item can do is show no name until the next fetch, so `load()` doesn't throw: a failed read is no account.
- **The Keychain, not `UserDefaults`:** a name and email are personal, so they get the same protection as the tokens: never in a backup, never readable by the widget.
- **The session's own accessibility:** the name shows whenever the session can be read, and #44's background job never needs it. Rejected: `WhenUnlocked`, which would add a second state to reason about for no gain.
- **Its own code, not a shared helper with `KeychainSessionStore`:** that would change how the session is saved in a release that must keep sign-in working (#134). The two stores are short, and their tests check the same attributes.
- **Cleared when a sign-in succeeds,** not only on sign-out: a session Buffer ended, or a sign-out whose Keychain delete failed, can leave the last account behind, and the next sign-in may be someone else's.
