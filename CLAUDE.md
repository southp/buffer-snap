# BufferSnap

Native iOS app (SwiftUI, iOS 18+, Swift 6 strict concurrency) with a terminal-only dev loop.
Never open the Xcode GUI to build, run, or test. Use the `just` recipes below.

Decisions and their reasons live in [`docs/decisions.md`](docs/decisions.md). Append a row whenever you make one.

## Commands

| Recipe | What it does |
|---|---|
| `just bootstrap` | One-time setup: checks Xcode is selected, installs missing CLI tools, creates the pinned simulator, enables `.githooks` |
| `just gen` | Generates `BufferSnap.xcodeproj` from `project.yml` (the project is gitignored; edit `project.yml`, never the `.xcodeproj`) |
| `just build` | Builds the app for the iOS Simulator |
| `just test` | Runs the unit tests on the pinned simulator (`SIM_DEVICE` / `SIM_OS`, overridable via env) |
| `just run` | Builds, installs and launches the app on the pinned simulator |
| `just lint` | `swift format lint --strict` + `swiftlint --strict` on `src_dirs`; also runs as the pre-commit hook |
| `just format` | Fixes formatting in place, then `swiftlint --fix` |
| `just clean` | Removes `build/` and the generated project |

When you add a source folder, append it to `src_dirs` at the top of `justfile` so it gets linted.

## Layout

- `project.yml`: XcodeGen spec (targets, settings, scheme)
- `App/`: the `BufferSnap` app target
- `AppTests/`: the `BufferSnapTests` unit-test target (Swift Testing)

## Workflow

- One issue → one branch (`issue/<N>-<slug>`) → one PR whose body contains `Closes #N`.
- Conventional commits in sentence case: `Type: Short description`, with a bullet body when needed.
  Keep commits small and self-contained; each one must build, lint and test on its own.
- Run `just test` **before** changing anything to get a baseline, so you can tell pre-existing failures from regressions.
- Run `just lint` and `just test` before every commit.
- Fix lint violations at the root; don't disable a rule without a documented reason in `docs/decisions.md`.
