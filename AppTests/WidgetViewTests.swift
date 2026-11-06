import SwiftUI
import Testing

/// The widget's faces, rendered to AppTests/__Snapshots__/WidgetViewTests/ at their size on the pinned iPhone 16, on a
/// plain background. The system draws the real background, so these show the content, not a whole Home Screen.
@MainActor
struct WidgetViewTests {
    /// The count and the one button that opens the capture screen.
    @Test func medium() {
        assertScreenSnapshot(of: homeScreenWidget(count: 12), named: "medium")
    }

    /// The widget on a new install, before anything is captured.
    @Test func mediumEmpty() {
        assertScreenSnapshot(of: homeScreenWidget(count: 0), named: "mediumEmpty")
    }

    /// The symbol on the round button. The circle behind it, `AccessoryWidgetBackground`, only draws in a real widget.
    @Test func lockScreen() {
        assertScreenSnapshot(of: SnapperLockScreenView().frame(width: 76, height: 76), named: "lockScreen")
    }

    /// `systemMedium` on iPhone 16, 338 × 158 points, inside the 16-point margin the system adds.
    private func homeScreenWidget(count: Int) -> some View {
        SnapperWidgetView(count: count)
            .padding(16)
            .frame(width: 338, height: 158)
            .background(Color(white: 0.92), in: .rect(cornerRadius: 22))
    }
}
