---
date: 2026-11-10
issue: 85
status: accepted
---

# Sign in on a page that doesn't share Safari's login

**Decision:** The web sign-in session sets `prefersEphemeralWebBrowserSession`, so Buffer's page starts with no cookies
each time and forgets them when it closes. People type their Buffer password (or use autofill or a passkey) at every
sign-in.

**Why:** When the page shared Safari's cookies, it was still signed in to whichever Buffer account was used last.
Choosing a different account from there made Buffer grant `ideas:write account:read` without `offline_access`, so no
refresh token came back, and the app turned the sign-in down with "Buffer couldn't finish signing you in". The retry
worked, because by then the page was signed in to the right account. Device logs of the granted scope showed the
switch losing `offline_access` every time, and the private page keeping it on every switch.

Rejected:

- **Retrying the sign-in on its own when the refresh token is missing.** It works around Buffer's behavior rather than
  avoiding it, and shows Buffer's approval page twice.
- **Accepting a session without a refresh token.** It would end silently after an hour.
- **Waiting for Buffer to fix it.** Worth reporting, but the first sign-in has to work now, App Review's included: a
  reviewer signs in to the demo account, which isn't the one in their Safari.

What it costs: no reuse of a Buffer login from Safari. iOS still asks "wants to use buffer.com to sign in" first.
