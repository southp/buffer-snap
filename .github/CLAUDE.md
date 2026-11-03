# GitHub workflows and PR review

## CI (`workflows/ci.yml`)

- Every PR and every push to `main` runs one job, `ci`: `just bootstrap`, `just lint`, `just test`, the same
  recipes you run locally. Branch protection on `main` requires it to pass. A newer push to the same branch cancels the older run.
- **Fast path:** a PR whose changed files are all on the safe list (`*.md`, `docs/*`, `LICENSE`,
  `workflows/claude.yml`, `workflows/claude-code-review.yml`) runs lint and Core tests only, in about 90s. Everything
  else takes the full path, as does every push to `main`. The "Choose the path" step prints its decision and the file
  list. The list is an allowlist in that step: add to it only what can't affect the app or its snapshots.
- It runs on the `xcode-27` image with Xcode 27.2 and, if the image has no runtime for the pinned simulator,
  downloads iOS runtime build `SIM_RUNTIME_BUILD` (`docs/decisions/6-*.md`). When you bump the pin, change `SIM_OS` and
  `SIM_RUNTIME_BUILD` in `justfile` and the Xcode path in `ci.yml` together (`xcrun simctl runtime list` shows your
  build), then re-record every snapshot.
- When it fails, the run's `test-artifacts` artifact has `build/snapshot-failures/` (the PNG CI rendered) and the
  `.xcresult` bundles: `gh run download <run-id> -n test-artifacts -D <dir>`. Compare that PNG with the reference in
  `AppTests/__Snapshots__/` before deciding anything. For the reference, failure and difference PNGs side by side,
  run `xcrun xcresulttool export attachments --path <dir>/DerivedData/Logs/Test/<name>.xcresult --output-path <out>`
  (`manifest.json` there names each file).
- The full path's cost is the simulator's first boot, which saturates the runner for minutes
  (`docs/decisions/27-no-early-simulator-boot.md`). Don't run other work alongside it.
- Keep truncated text out of snapshot fixtures: a truncated line can render 1px off on CI and fail a snapshot that
  passes locally (`docs/decisions/27-no-truncated-text-in-snapshots.md`). Don't lower the precision to absorb it.
- Don't add a matrix, or per-change test selection beyond the fast path. Caching is out of scope so far (#27).
- Renaming the `ci` job breaks the required check; change the branch rule with it.

## Claude review

- Every non-draft PR gets an automatic Claude review (`workflows/claude-code-review.yml`) when it's opened, marked
  ready, or pushed to. The review checks the PR against the `CLAUDE.md` files of the areas it touches and the
  acceptance criteria of the issue it `Closes`.
- Comment `@claude <request>` on a PR or issue to have Claude act on it (`workflows/claude.yml`), for example to push
  a fix to the PR branch. Only collaborators with write access can trigger it.
- Both Claude workflows run on Linux runners without Xcode, so Claude there can't run `just`. Run `just lint` and
  `just test` locally on anything it pushes before merging.
- New PRs are prefilled from `pull_request_template.md`. Fill in every section, including snapshot changes.
- Why the workflows are set up this way: `docs/decisions/12-*.md`.
