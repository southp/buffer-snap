---
date: 2026-11-05
issue: 43
status: accepted
---

# Return from Buffer sign-in through a static HTTPS page

**Decision:** The registered redirect URI is `https://southp.github.io/buffer-snap/oauth/`, a static page in `site/oauth/` that forwards its query string to `buffersnap://oauth`, which `ASWebAuthenticationSession` catches.

**Why:** Buffer refused `buffersnap://oauth`, and its guide requires HTTPS. The page needs no server or secret, and only `site/` is published. The authorization code passes through the page's URL, but it's useless without the PKCE verifier, which never leaves the app. Rejected: a Universal Link, which needs `apple-app-site-association` at a domain's root (a project page isn't one) and adds an Associated Domains capability to the App IDs; a server of our own.
