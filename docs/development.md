# Development

Everything runs from the terminal through [`just`](https://github.com/casey/just) recipes, without opening the Xcode GUI.

Project conventions are in [`CLAUDE.md`](../CLAUDE.md), how the app fits together is in
[`architecture.md`](architecture.md), and the reasoning behind tooling choices is in [`decisions/`](decisions/).

## Prerequisites
- Xcode with the iOS platform installed and selected, plus `xcodegen`, `swiftlint` and `xcbeautify` (see [#8](https://github.com/southp/buffer-snap/issues/8)). `just bootstrap` installs any that are missing, plus `xcode-build-server`
- `just` (`brew install just`)

## Getting started
```sh
just bootstrap   # check Xcode, install missing tools, create the pinned simulator, enable git hooks
just run         # build and launch the app in the iPhone Simulator
```

## Recipes
Run `just --list` to see every recipe and what it does.

## Deploying to TestFlight
Every merge to `main` deploys on its own: once `ci` passes, a new build goes to TestFlight.

To upload from your machine, `just deploy` archives, signs and uploads a build. Your iPhone then offers it as an update in the TestFlight app.

One-time setup, after the Apple account steps in [#11](https://github.com/southp/buffer-snap/issues/11):

```sh
cp .env.example .env   # gitignored; then fill in your team ID and API key details
just deploy
```

The recipe stops before building if a value or the API key file is missing, or if the git tree is dirty, so every build matches a commit. Certificates and profiles are managed by Apple through the API key, so none live in this repo.

## Testing on your iPhone
`just device` builds, installs and launches on your phone, with no TestFlight round trip. It's how to test anything that behaves differently on a real or locked device.

One-time setup:

1. Add the phone to your developer account at [developer.apple.com/account/resources/devices](https://developer.apple.com/account/resources/devices). The build can't do this through the API key.
2. Put its identifier in `.env` as `DEVICE_ID`. `xcrun devicectl list devices` shows it.

The phone must be connected and unlocked. This replaces the TestFlight build until you install from TestFlight again.

## Editor setup
Any editor with LSP support works through Apple's `sourcekit-lsp`, which ships with Xcode. Run `just lsp` once per clone: it writes `buildServer.json` so the language server knows every target's build settings, which enables go-to-definition, references and diagnostics across files and targets.

For Neovim 0.11+ with [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), add `vim.lsp.enable('sourcekit')` to your config.

- Run `just lsp` once per clone or worktree, and again after adding a **target**.
- A new **file** resolves after the next `just build` or `just test` (both regenerate the project first).
- The build server reads compiler flags from build logs in `build/DerivedData`, so `just clean` drops context until the next build.

## Parallel worktrees
Each git worktree gets its own simulator (`iPhone 16 (worktree: <dir>)`), so tests in different worktrees can run at the same time. After removing worktrees, run `just sims-prune` to delete their simulators.

## Releasing
What each version brought, and what's next: [`release-notes.md`](release-notes.md). Submitting a version to the App
Store, step by step: [`app-store/checklist.md`](app-store/checklist.md).
