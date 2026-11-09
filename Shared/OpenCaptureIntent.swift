import AppIntents

/// What the control and every widget button run: opens the app on the capture screen.
///
/// `openAppWhenRun` only works if the intent is compiled into both the app and the widget, so this file is in both
/// targets. The widget can't reach the app's `AppModel`, so the app says what to do through `onRun`, which stays `nil`
/// in the widget's process (`docs/decisions/41-open-capture-hook.md`).
struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture an Idea"
    static let description = IntentDescription("Opens BufSnap on the capture screen.")
    static let openAppWhenRun = true
    // Only the control and the widget's buttons run this; it has no place in Shortcuts or Spotlight.
    static let isDiscoverable = false

    /// Set once by the app at launch. It's main-actor isolated, and so is `perform()`, which can't start until the main
    /// actor is free. That's after the app's `init`, even when this intent is what launched the app.
    @MainActor static var onRun: (@MainActor () -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.onRun?()
        return .result()
    }
}
