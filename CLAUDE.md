# BufferSnap

Native iOS app (SwiftUI, iOS 18+, Swift 6 strict concurrency) with a terminal-only dev loop.
Never open the Xcode GUI to build, run, or test. Use the `just` recipes below.

Decisions and their reasons live in [`docs/decisions/`](docs/decisions/), one file per decision. See its README for the format.

## Commands

| Recipe | What it does |
|---|---|
| `just bootstrap` | One-time setup: checks Xcode is selected, installs missing CLI tools, creates the pinned simulator, enables `.githooks` |
| `just gen` | Generates `BufferSnap.xcodeproj` from `project.yml` (the project is gitignored; edit `project.yml`, never the `.xcodeproj`) |
| `just build` | Builds the app for the iOS Simulator |
| `just test` | Runs the unit tests on the pinned simulator (`SIM_DEVICE` / `SIM_OS`, overridable via env) |
| `just run` | Builds, installs and launches the app on the pinned simulator |
| `just lsp` | Writes `buildServer.json` (gitignored) and compiles every target, so `sourcekit-lsp` understands the project |
| `just lint` | `swift format lint --strict` + `swiftlint --strict` on every Swift file git knows about; also runs as the pre-commit hook |
| `just format` | Fixes formatting in place, then `swiftlint --fix` |
| `just clean` | Removes `build/` and the generated project |

## Editor (language server)

`sourcekit-lsp` (ships with Xcode) gets project context from `xcode-build-server` through `buildServer.json`.

- Run `just lsp` once per clone or worktree, and again after adding a **target** to `project.yml`.
- A new **file** resolves after the next `just build` / `just test` (both regenerate the project first).
- The build server reads compiler flags from build logs in `build/DerivedData`, so `just clean` drops context until the next build.

## Layout

- `project.yml`: XcodeGen root spec (project settings, scheme); includes each target's `target.yml`
- `App/`: the `BufferSnap` app target (`App/target.yml`)
- `AppTests/`: the `BufferSnapTests` unit-test target, Swift Testing (`AppTests/target.yml`)

## Workflow

- One issue → one branch (`issue/<N>-<slug>`) → one PR whose body contains `Closes #N`.
- Conventional commits in sentence case: `Type: Short description`, with a bullet body when needed.
  Keep commits small and self-contained; each one must build, lint and test on its own.
- Run `just test` **before** changing anything to get a baseline, so you can tell pre-existing failures from regressions.
- Run `just lint` and `just test` before every commit.
- Fix lint violations at the root; don't disable a rule without a documented reason in `docs/decisions/`.

## PR review

- Every non-draft PR gets an automatic Claude review (`.github/workflows/claude-code-review.yml`) when it's opened, marked ready, or pushed to. The review checks the PR against this file and the acceptance criteria of the issue it `Closes`.
- Comment `@claude <request>` on a PR or issue to have Claude act on it (`.github/workflows/claude.yml`), for example to push a fix to the PR branch. Only collaborators with write access can trigger it.
- Both workflows run on Linux runners without Xcode, so Claude there can't run `just`. Run `just lint` and `just test` locally on anything it pushes before merging.
- New PRs are prefilled from `.github/pull_request_template.md`. Fill in every section, including snapshot changes.
