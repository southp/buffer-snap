import SwiftUI
import Testing
import WidgetKit

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

    /// A tinted or clear Home Screen draws the face in one color, by its shapes' opacity, without its Sun background.
    /// The circle is only an outline there, so the symbol stays visible. Rendered in ink on a light stand-in, before
    /// the system tints it.
    @Test func dictateTinted() {
        let tinted = DictateWidgetView()
            .environment(\.widgetRenderingMode, .accented)
        assertScreenSnapshot(of: framed(tinted, background: Color(white: 0.9)), named: "dictate-tinted")
    }

    /// StandBy and the Lock Screen draw the face vibrant: one color by opacity too, so it takes the same outline path.
    @Test func dictateVibrant() {
        let vibrant = DictateWidgetView()
            .environment(\.widgetRenderingMode, .vibrant)
        assertScreenSnapshot(of: framed(vibrant, background: Color(white: 0.9)), named: "dictate-vibrant")
    }

    private var widget: some View {
        framed(DictateWidgetView(), background: DictateWidgetBackground())
    }

    private func framed(_ face: some View, background: some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return
            face
            .padding(16)
            .frame(width: 158, height: 158)
            .background {
                background
            }
            .containerShape(shape)
            .clipShape(shape)
    }
}
