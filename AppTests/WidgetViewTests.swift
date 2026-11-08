import SwiftUI
import Testing

/// The widgets' faces, rendered to AppTests/__Snapshots__/WidgetViewTests/ at their size on the pinned iPhone 16, on a
/// plain background. The system draws the real background, so these show the content, not a whole Home Screen.
@MainActor
struct WidgetViewTests {
    /// How many captures are waiting to send, and the one button that opens the capture screen.
    @Test func medium() {
        assertScreenSnapshot(of: homeScreenWidget(count: 12), named: "medium")
    }

    /// Nothing waiting: on a new install, or once everything has gone.
    @Test func mediumEmpty() {
        assertScreenSnapshot(of: homeScreenWidget(count: 0), named: "mediumEmpty")
    }

    /// The symbol on the round button. The circle behind it, `AccessoryWidgetBackground`, only draws in a real widget.
    @Test func lockScreen() {
        assertScreenSnapshot(of: SnapperLockScreenView().frame(width: 76, height: 76), named: "lockScreen")
    }

    /// The dictation widget: one mic button that starts listening without opening the app.
    @Test func dictate() {
        let widget = DictateWidgetView()
            .padding(16)
            .frame(width: 158, height: 158)
            .background(Color(white: 0.92), in: .rect(cornerRadius: 22))
        assertScreenSnapshot(of: widget, named: "dictate")
    }

    /// `systemMedium` on iPhone 16, 338 × 158 points, inside the 16-point margin the system adds.
    private func homeScreenWidget(count: Int) -> some View {
        SnapperWidgetView(waitingCount: count)
            .padding(16)
            .frame(width: 338, height: 158)
            .background(Color(white: 0.92), in: .rect(cornerRadius: 22))
    }
}
