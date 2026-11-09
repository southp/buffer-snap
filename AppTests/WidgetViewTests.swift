import SwiftUI
import Testing

/// The widget's face, rendered to AppTests/__Snapshots__/WidgetViewTests/ at its size on the pinned iPhone 16, on a
/// plain background. The system draws the real background, so this shows the content, not a whole Home Screen.
@MainActor
struct WidgetViewTests {
    /// The dictation widget: one mic button that starts listening without opening the app.
    @Test func dictate() {
        let widget = DictateWidgetView()
            .padding(16)
            .frame(width: 158, height: 158)
            .background(Color(white: 0.92), in: .rect(cornerRadius: 22))
        assertScreenSnapshot(of: widget, named: "dictate")
    }
}
