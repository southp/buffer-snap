---
date: 2026-11-17
issue: 108
status: accepted
---

# Load the account's picture from Buffer's S3 bucket, and from nowhere else

**Decision:** The toolbar chip shows the account's profile picture from Buffer's `Account.avatar`, which points to
`buffer-account-avatars-bucket.s3.amazonaws.com`, Buffer's own bucket on Amazon S3, not a `*.buffer.com` host. The owner
chose to allow exactly that host (#108). `BufferAccount.isAllowedAvatarURL(_:)` keeps a URL only if its scheme is
`https`, its host is exactly that string, as written (no lookalike suffix, other bucket, percent-encoding or case
change), and it has no port or user. Every `BufferAccount` goes through it, from Buffer or from the Keychain, and
`HTTPAvatarDownloader` checks again before any request. Its session follows no redirect. The picture is kept by
`FileAvatarImageStore` in Application Support, and the URL is never logged.

**Why:**

- **One exact host, not a pattern:** `*.amazonaws.com` or `*.s3.amazonaws.com` would let a URL reach any bucket on S3,
  anyone's. Matching the host string exactly is the only check that can't be fooled by a suffix such as
  `buffer-account-avatars-bucket.s3.amazonaws.com.evil.example`. If Buffer moves its pictures, the chip falls back to
  initials until this constant changes, which is the safe way to fail.
- **No redirects:** S3 could answer with a redirect to another host, and following it would break "nothing else is ever
  requested". A redirect comes back as a non-200 and counts as a failed download.
- **The privacy answers don't change:** the request sends nothing but itself (no token, no cookies), and the picture stays
  on the iPhone, so nothing is collected. The privacy page names the host, as it's a second place the app connects to.
- **Application Support, not the App Group or `URLCache`:** the widget never shows the picture, so it doesn't share it,
  and `URLCache` has no place in sign-out's cleanup. The file is readable after first unlock, like the account's
  Keychain item, so it shows from the first frame, and its folder is out of backups, as the Keychain item is
  (`92-account-cache.md`).
- **Named after a hash of its URL:** the store has to know which URL its picture came from, to download only when it
  changes. A SHA-256 of the URL tells it without writing down the URL, which holds the account's ID.
- **At most once per URL per launch:** a failed URL isn't asked for again until the next launch, so a broken picture
  can't turn into a request at every foreground. Rejected: remembering failures across launches, which would leave a
  picture that failed once on a bad connection missing for good.
- **Not through `SubmissionQueue`:** it's S3, not Buffer's API, so it doesn't count toward Buffer's rate limit
  (`105-say-when-buffer-asks-to-wait.md`), and a slow or failed download never holds back an idea.
