---
date: 2026-11-05
issue: 43
status: accepted
---

# Refresh tokens in one actor, and accept what a crash costs

**Decision:** `OAuthAuthService` is the one place that refreshes, and there's one instance, in the app's process. All callers during a refresh wait for one request, which runs in its own task, and the new session is saved before any caller gets a token. Only `invalid_grant` ends a session.

**Why:** Buffer's refresh tokens are single-use, and using one twice revokes every token for the grant. So:

- **Own task:** a cancelled caller, such as a background task out of time, can't cancel a request Buffer may already have acted on. Its response has the only copy of the next refresh token.
- **Save fails:** the new session stays in memory, because the saved refresh token is now dead. No caller gets a token until a save works, and no second refresh goes out with the old token.
- **Only `invalid_grant`:** the guide's other token errors, a 5xx, a 429 or an unreadable body say nothing about the token, and neither does a failed connection. All of them leave the session to try again later.

**What can still go wrong:** Buffer rotates the token, and the app never saves the result, because it crashed, was killed, or lost the response. The Keychain still has the old token, the next refresh sends it, Buffer revokes the grant and answers `invalid_grant`, and the user lands on sign-in with a message saying why. Nothing else is lost: captures are in their own store, and the new tokens were never saved, so the revocation takes nothing we hold.

Nothing on the client can close this window, as no write can be atomic with a server's response. Rejected: marking "refresh in flight" in the Keychain before each request, to skip the doomed retry at the next launch. A marker can't tell whether Buffer acted on the request, so it would sign out people whose token is still good, to avoid a rejection that costs the same sign-in.

The access token is refreshed a minute before it expires, as the guide advises, and also after `accessTokenRejected(_:)` reports a 401 from the API. `AppModel` also checks the session whenever the app comes to the foreground, so a dead session shows up there, even before anything needs a token.

Nothing refreshes from a widget or control process, because a second process would be a second refresher. Rejected: coordinating processes with a lock in the App Group, as nothing needs it. #44's job runs in the app's process.
