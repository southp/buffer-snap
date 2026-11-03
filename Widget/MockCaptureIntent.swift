import AppIntents
import BufferSnapCore

/// What a Snapper button does: appends a mock capture to the shared store, without opening the app.
///
/// WidgetKit reloads the widget's timelines by itself once `perform()` returns, so the count updates.
struct MockCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture"
    // Only the widget's buttons run this; it has no place in Shortcuts or Spotlight.
    static let isDiscoverable = false

    @Parameter(title: "Kind")
    var kind: CaptureKindAppEnum

    init() {}

    init(kind: CaptureKindAppEnum) {
        self.kind = kind
    }

    func perform() async throws -> some IntentResult {
        let store = JSONFileCaptureStore(fileURL: try SharedStorage.capturesFileURL())
        try await store.add(.mock(kind: kind.captureKind))
        return .result()
    }
}
