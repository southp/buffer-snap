---
date: 2026-11-05
issue: 44
status: accepted
---

# What gets retried, and what shows as failed

**Decision:** Every failure from Buffer falls into one of these. Only "Failed" shows on the capture, and only Resend takes it out again.

| What happened | What the queue does |
|---|---|
| No answer: offline, timeout, dropped connection | Stays pending. Stops the pass and backs off, with no limit |
| 429, or `RATE_LIMIT_EXCEEDED` | Stays pending. Nothing goes out for `Retry-After` seconds plus up to 5 seconds of jitter, whatever triggers a run. With no usable `Retry-After`, it waits like a back-off |
| 401, `UNAUTHORIZED`, `UNAUTHENTICATED` | `accessTokenRejected` and try again with a new token. Twice in a pass stops it and backs off |
| The refresh says the session is over | Stays pending. Stops without a timer, and the foreground routes to sign-in |
| Can't get a token for now (`AuthError.network`, `.server`, `.storage`) | Stays pending, and backs off |
| 408, 5xx, `UNEXPECTED`, `UnexpectedError`, a 2xx we can't read | Stays pending and backs off, up to 5 times per capture, then **Failed** |
| `InvalidInputError`, `LimitReachedError`, `UnauthorizedError`, `FORBIDDEN`, `NOT_FOUND`, any other code or type, other 4xx | **Failed**, and the next capture goes on |
| No organization, or the lookup is refused | **Failed**. If the lookup only fails for now, the capture stays pending without counting against it, as a read creates nothing |

The back-off doubles from 5 seconds up to 15 minutes. Only a rate limit holds back a new run. A new trigger, such as connectivity returning or the app coming to the foreground, doesn't wait out a back-off.

**Why:**

- **Unknown means failed:** Buffer only ever adds to its schema, so a new code or type will turn up. If it can't succeed, retrying it would run forever without anyone seeing. As failed, the worst case is one tap on Resend.
- **`LimitReachedError` fails right away:** nothing says when a limit like that would lift, so only a person can act on it.
- **A rate limit isn't remembered across launches:** a 429 doesn't use up any quota or extend the wait, the guide says, so one more request after a relaunch costs nothing. It's not worth persisting.
- **A long wait stays "Pending":** a 30-day limit can mean weeks. Nothing is lost by waiting, and Buffer has said no sooner.
- **No throttling before the limit:** the guide suggests slowing down as `RateLimit` runs low. A person's captures come nowhere near 100 requests in 15 minutes, so this can wait until there are enough users for it to matter.
