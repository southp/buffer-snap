# Decision log

Append-only. Add new rows at the bottom; don't edit past rows. Supersede a decision with a new row that links to the old one.

| Date | Decision | Why | Issue |
|---|---|---|---|
| 2026-10-31 | Generate the Xcode project with **XcodeGen** (`project.yml`); `*.xcodeproj` is gitignored | Reviewable YAML instead of `pbxproj` merge conflicts; fits a terminal-only workflow | #1 |
| 2026-10-31 | Use **`just`** as the task runner | One discoverable entry point (`just --list`) for every dev command, shared by humans, Claude and CI | #1 |
| 2026-10-31 | **swift-format** (bundled with the toolchain) formats; **SwiftLint** lints | No extra install for formatting; SwiftLint covers semantic rules swift-format doesn't | #1 |
| 2026-10-31 | Target **iOS 18**, **Swift 6** language mode (strict concurrency) | Modern SwiftUI/`@Observable`/widget APIs; catch data races at compile time from day 1 | #1 |
| 2026-10-31 | Deploy with plain **`xcodebuild`** archive/export, an **App Store Connect API key** and automatic signing; no fastlane | Fewer moving parts and no Ruby toolchain for a solo project | #2 |
| 2026-10-31 | Architecture: shared pure-Swift **SPM Core** package; `@Observable` view models over `Sendable` service protocols with mocks | Core stays UI-free and testable with `swift test`; mocks let every component connect end to end before it's real | #5 |
| 2026-10-31 | UI feedback loop: **snapshot playground** (swift-snapshot-testing) + **XcodeBuildMCP** for Claude Code | Lets Claude see and verify UI without the Xcode GUI | #13 |
| 2026-10-31 | Widget ↔ app storage: a **JSON file in the App Group** container | Simplest store both processes can read; enough for the mocked scaffolding | #5 |
| 2026-10-31 | Automated PR review by **Claude** using subscription OAuth | Reuses the existing subscription; no separate API billing | #12 |
| 2026-11-02 | Pin tests to the **iPhone 16** simulator on **iOS 27.2** (`SIM_DEVICE` / `SIM_OS`); `just bootstrap` creates it if missing | Matches the developer's own phone; Xcode 27.2 has the device type but ships no iPhone 16 device, so fresh clones and CI must create it | #1 |
| 2026-11-02 | Configure SwiftLint `trailing_comma` with `mandatory_comma: true` | swift-format adds trailing commas to multi-line collections, which the default rule rejects; requiring them makes the two tools agree instead of disabling a rule | #1 |
