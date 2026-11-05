---
date: 2026-11-05
issue: 43
status: accepted
---

# Keep the session in one app-private Keychain item

**Decision:** `KeychainSessionStore` keeps the access token, the refresh token and the expiry as one JSON generic-password item, with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and no access group. It replaces the item with `SecItemUpdate`, and only adds one if there's none.

**Why:**

- **One item:** the tokens can't get out of step, as two items could if a crash came between the writes. Updating in place, not deleting and adding, leaves no moment without a copy of the refresh token.
- **After first unlock:** #44's background job can read it while the iPhone is locked. `WhenUnlocked` would make that job fail.
- **This device only:** a backup restored elsewhere would bring back a single-use refresh token, and using it twice revokes the grant.
- **No access group, no entitlement:** only the app's process needs the tokens. Without an access group, an item lands in the first group the app holds. That's its own `application-identifier`, because it has no `keychain-access-groups` and App Groups come after it. So nothing changes for the API key, which can't assign capabilities to App IDs, or for `just deploy`'s ad hoc signing, and the widget can't read the tokens. `KeychainSessionStoreTests` checks the item isn't in the App Group. Rejected: sharing the item with the widget, as a second process refreshing would be a second refresher, and that revokes the session.

Failing to read isn't the same as finding nothing: `load()` throws for anything but `errSecItemNotFound`, so a locked Keychain can't sign anyone out. The Keychain outlives the app, so reinstalling restores the session. Rejected: clearing it on the first launch after an install, as that needs a marker in `UserDefaults`, and a stale session only gets rejected and sends the user to sign-in.
