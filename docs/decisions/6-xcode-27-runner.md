---
date: 2026-11-02
issue: 6
status: accepted
---

# Run CI on the `xcode-27` runner image with Xcode 27.2 selected

**Decision:** The `ci` job runs on GitHub's `xcode-27` image (arm64, macOS 27, preview) and selects
`/Applications/Xcode_27.2.app`. The image has no iOS 27.2 simulator runtime, so CI downloads the build developers
have locally (`SIM_RUNTIME_BUILD`, 24B8117) with `xcodebuild -downloadPlatform iOS`, and skips that once the image
ships a runtime that runs `SIM_DEVICE`.

**Why:** It's the only hosted image with Xcode 27.2: `macos-15` (which the issue named) and `macos-26` stop at
Xcode 26, whose iOS 26 runtimes would render snapshots differently from the iOS 27.2 ones recorded locally. Changing
the local pins to fit an image was rejected (#6 asks for the reverse). Known gaps: the image is a preview (it may
queue longer), and its 27.2 is the release candidate (build 27B48, local is 27B52); the `Xcode_27.2.app` symlink
follows the image when it moves to the release build. The runtime is pinned by build, not by `SIM_OS`, because
`-buildVersion 27.2` fetches a device-specific runtime (iOS-27-2-iPhone19-4) that has no iPhone 16.
