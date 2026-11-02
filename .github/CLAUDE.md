# GitHub workflows and PR review

## CI (`workflows/ci.yml`)

- Every PR and every push to `main` runs one job, `ci`: `just bootstrap`, `just lint`, `just test`, the same
  recipes you run locally. Branch protection on `main` requires it to pass. A newer push to the same branch cancels the older run.
- It runs on the `xcode-27` image with Xcode 27.2 and, if the image has no runtime for the pinned simulator,
  downloads iOS runtime build `SIM_RUNTIME_BUILD` (`docs/decisions/6-*.md`). When you bump `SIM_OS` in `justfile`,
  bump the Xcode path and `SIM_RUNTIME_BUILD` in `ci.yml` with it (`xcrun simctl runtime list` shows your build).
- When it fails, the run's `test-artifacts` artifact has `build/snapshot-failures/` (the PNG CI rendered) and the
  `.xcresult` bundles: `gh run download <run-id> -n test-artifacts`. Compare that PNG with the reference in
  `AppTests/__Snapshots__/` before deciding anything.
- Don't add caching, a matrix or per-change test selection until CI time is a real problem (#6).
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
