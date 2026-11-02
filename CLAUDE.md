# BufferSnap

Native iOS app (SwiftUI, iOS 18+, Swift 6 strict concurrency) with a terminal-only dev loop.
Never open the Xcode GUI to build, run, or test.

This file holds only **repo-wide rules that rarely change**. Don't add per-issue sections here: put them where
"Where things go" says.

## Commands

Run `just --list`. Each recipe's comment in `justfile` is its documentation, so there's no recipe table here.

## Where things go

| What | Where |
|---|---|
| Notes for one area (conventions, gotchas) | That area's `CLAUDE.md`, e.g. `App/CLAUDE.md`. Claude Code loads it when you work in that folder |
| A decision and why it was made | A new `docs/decisions/<issue>-<slug>.md` (format in [`docs/decisions/README.md`](docs/decisions/README.md)) |
| A target's sources, settings and dependencies | That target's `target.yml` (e.g. `App/target.yml`). Only project-wide settings and the scheme go in `project.yml` |
| A new Swift folder | Nothing to register: `just lint` covers every Swift file git knows about. A new target needs its `target.yml` added to `include:` in `project.yml` |

## Working in parallel

Several agents work at once, one per issue, each in its own git worktree.

- Work only inside your worktree (`.worktrees/issue-<N>-<slug>`, branch `issue/<N>-<slug>`). Never edit the main
  checkout or another worktree.
- Never `git checkout`/`git switch` to another branch, and never run a bare `git stash`: the stash is shared by
  every worktree.
- Edit only the area `CLAUDE.md` files your issue names. If another area needs a change, say so in the PR.
- Your worktree has its own `build/` and its own simulator (`iPhone 16 (worktree: <dir>)`); `just` picks both
  automatically. If a tool needs the device, use `just _sim-udid`, never another worktree's simulator.

## Workflow

- One issue → one branch (`issue/<N>-<slug>`) → one PR whose body contains `Closes #N`.
- Conventional commits in sentence case: `Type: Short description`, with a bullet body when needed.
  Keep commits small and self-contained; each one must build, lint and test on its own.
- Run `just test` **before** changing anything to get a baseline, so you can tell pre-existing failures from regressions.
- Run `just lint` and `just test` before every commit.
- Fix lint violations at the root; don't disable a rule without a documented reason in `docs/decisions/`.
- Every PR gets an automatic Claude review, and `@claude` can push fixes (see `.github/CLAUDE.md`). Claude in CI
  can't run `just`, so run `just lint` and `just test` locally on anything it pushes before merging.
