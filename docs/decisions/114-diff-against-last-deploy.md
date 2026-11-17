---
date: 2026-11-17
issue: 114
status: accepted
---

# A push to `main` diffs against the last deployed commit

**Decision:** On a push to `main`, the `changes` job compares `HEAD` with the last commit that `deploy` shipped,
not with `github.event.before`. It lists the last 20 successful push runs of `ci.yml` on `main`, newest first, and
takes the head commit of the first one whose `deploy` job concluded `success`. It fetches that commit alone with
`git fetch --depth=1` and logs it. The full path runs if that lookup finds no deploy in those 20 runs, if an API call
fails, if a run's commit isn't a 40-character hash, or if the fetch fails. PRs are unchanged: they diff the merge
commit against its first parent. Only `changes` gets `actions: read`, and it has none of `deploy`'s secrets.

This supersedes `102-docs-only-skips-ci.md` for what a push to `main` compares against, and drops its accepted
cost. The rest of 102 still holds: the safe list, the PR diff, and running `ci` unless `full` is exactly `false`.

**Why:** Comparing with `before` left code undeployed with nothing turning red. If a code merge's run was dropped from
the concurrency queue, or its `ci` or `deploy` failed or was cancelled, and the next merge was docs-only, that run saw
only docs and skipped, so the code waited for someone to notice and re-run it. Diffing against what TestFlight
actually has makes the next merge pick that code up and deploy it.

"Deployed" means the `deploy` job succeeded, not the run: a docs-only run also succeeds, with `ci` and `deploy`
skipped, so the last successful run's commit would hide the undeployed code again. The run list is filtered to
`status=success` because a run whose `deploy` succeeded always succeeds, and that keeps the 20 runs the bound covers to
ones that could have deployed. The bound keeps the lookup to at most 21 API calls, however many docs-only merges came
in a row. Every doubt takes the full path: an extra full run costs minutes of a macOS runner, a wrong skip leaves
code off TestFlight.

Rejected: the last successful run's `head_sha`, for the reason above. `fetch-depth: 0` to reach the deployed commit,
because it also downloads the `pr-media` binaries. Keeping `before` and documenting the re-run by hand, which is the
cost this removes.
