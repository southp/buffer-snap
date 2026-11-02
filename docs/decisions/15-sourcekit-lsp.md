---
date: 2026-11-02
issue: 15
status: accepted
---

# Editor support via sourcekit-lsp and xcode-build-server

**Decision:** Editor support via Apple's **`sourcekit-lsp`** + **xcode-build-server** (`just lsp` writes a gitignored `buildServer.json`)

**Why:** On its own, sourcekit-lsp only understands SwiftPM packages; the build server feeds it each Xcode target's real compiler flags, enabling cross-file and cross-target navigation in any LSP editor (Neovim here)
