---
date: 2026-11-12
issue: 102
status: accepted
---

# Skip `ci` and `deploy` for docs-only changes, on PRs and on `main`

**Decision:** A `changes` job on `ubuntu-latest` lists the changed files and sets `full`. A PR diffs its merge commit
against its first parent. A push to `main` diffs `github.event.before` against the pushed commit, after fetching
`before` alone with `git fetch --depth=1`. If every file is on the safe list, the `ci` job is skipped by its `if:`, and
`deploy`, which `needs: [ci]`, is skipped with it. Otherwise `ci` always takes the full path: `just bootstrap`,
`just lint`, `just test`. This supersedes `27-docs-only-fast-path.md`, whose PR-only fast path still started a macOS
runner, and which put every docs-only merge through the full path and onto TestFlight.

The safe list, and why each entry can't change the app or its snapshots:

| Pattern | Why it's safe |
|---|---|
| `*.md` (any depth) | Target specs exclude Markdown from bundles, so each area's `CLAUDE.md` and the PR template are never built |
| `docs/*` | Nothing in `project.yml`, the `target.yml` files or `justfile` reads it |
| `site/*` | Only `pages.yml` reads it (`git grep -n 'site/' -- '*.yml' justfile`), and it publishes on its own trigger |
| `LICENSE` | Not an input to any target |
| `claude.yml`, `claude-code-review.yml` | Review workflows; they don't run in `ci` or reach the app |

Everything else takes the full path, `ci.yml` and `justfile` included, and so does any case where the changed files
are unknown: a PR head that isn't a merge commit, a `before` of all zeros or one that can't be fetched, an empty diff,
any other event, or a failed `changes` job. For that last one `ci` runs when `full` isn't exactly `false`, not when it
is `true`, so a broken `changes` job can't turn into a skipped, passing `ci`.

**Why:** A docs-only PR waited for an `xcode-27` runner to lint and run Core tests its files can't affect, and a
docs-only merge ran the simulator for 12 minutes and shipped a TestFlight build with no code change. The ruleset
"Protect main" requires a check named `ci`. A job skipped by `if:` still reports `ci`, as skipped, and GitHub counts a
skipped required check as passing, so the PR stays mergeable. Keep the job id `ci` for that.

Rejected: `paths-ignore` on the workflow, because a workflow that never starts reports no `ci` at all and the required
check waits forever. `fetch-depth: 0` to reach `before`, because it also downloads the `pr-media` binaries. Keeping the
fast path's lint and Core tests on docs-only PRs, because those files can't affect either.

Accepted cost: runs on `main` share a concurrency group that keeps only one waiting run (`9-deploy-on-merge.md`). If a
code merge's run is dropped that way and the newest waiting merge is docs-only, the newest run compares against the
dropped commit, finds only docs and skips. The code merge was tested on its PR, and it reaches TestFlight with the next
merge that takes the full path, or when its own run is re-run from the Actions tab.
The same goes for a code merge whose `ci` run fails or is cancelled: if the next merge is docs-only, it compares
only against that commit and skips, so re-run the failed run once it's fixed.
