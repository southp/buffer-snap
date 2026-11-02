---
date: 2026-11-02
issue: 5
status: accepted
---

# Keep Core UI-free with a SwiftLint rule

**Decision:** A SwiftLint custom rule (`no_ui_import_in_core`) fails `just lint` on any `import` of SwiftUI,
SwiftUICore, UIKit, AppKit or WidgetKit in a file under `Packages/BufferSnapCore/`, sources and tests alike.

**Why:** The compiler can't enforce it: SwiftUI and AppKit exist on macOS, so the package still builds and passes
`swift test` with a UI import. AppKit and SwiftUICore are banned on top of the issue's list because they are the
same loophole on macOS. The rule skips comments and strings, so docs can name the frameworks.
