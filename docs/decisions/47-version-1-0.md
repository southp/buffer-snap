---
date: 2026-11-08
issue: 47
status: accepted
---

# Ship the first App Store version as 1.0

**Decision:** `MARKETING_VERSION` goes from `0.1.0` to `1.0`, and the first App Store version is 1.0. The build number
stays the UTC timestamp `just deploy` sets.

**Why:** App Store Connect offers a build for a version only when the build's version string matches the version's,
and it names a new app's first version `1.0`. Matching that means the owner picks the build without renaming anything.
It's also what the README's delivery plan calls this release: v1. Rejected: keeping `0.1.0`, which works if the
version is renamed in App Store Connect, but reads as a beta on the product page.

Every merge to `main` keeps uploading 1.0 builds to TestFlight. Once 1.0 is approved, App Store Connect refuses more
builds of it, so the first change after the release raises the version (e.g. to `1.0.1` or `1.1`) in `project.yml`.
