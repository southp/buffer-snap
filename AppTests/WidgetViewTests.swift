import SwiftUI
import Testing

/// The widget's face, rendered to AppTests/__Snapshots__/WidgetViewTests/ at its size on the pinned iPhone 16, on its
/// own background with the Home Screen's corners. This shows the widget, not a whole Home Screen.
@MainActor
struct WidgetViewTests {
    /// The dictation widget: one button, with BufSnap's dictate symbol, that starts listening without opening the app.
    @Test func dictate() {
        assertScreenSnapshot(of: widget, named: "dictate")
    }

    /// Sun stays Sun in dark mode, and so does the ink on it.
    @Test func dictateDark() {
        assertScreenSnapshot(of: widget, named: "dictate-dark", appearance: .dark)
    }

    private var widget: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return DictateWidgetView()
            .padding(16)
            .frame(width: 158, height: 158)
            .background {
                DictateWidgetBackground()
            }
            .containerShape(shape)
            .clipShape(shape)
    }
}
