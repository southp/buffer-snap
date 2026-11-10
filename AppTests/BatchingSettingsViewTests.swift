import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The batching setting, rendered full-screen to AppTests/__Snapshots__/BatchingSettingsViewTests/.
@MainActor
struct BatchingSettingsViewTests {
    /// What a new install has.
    @Test func standard() {
        assertScreenSnapshot(of: screen(window: BatchWindow.standard), named: "fiveMinutes")
        assertScreenSnapshot(of: screen(window: BatchWindow.standard), named: "fiveMinutes-dark", appearance: .dark)
    }

    /// Each capture goes by itself.
    @Test func off() {
        assertScreenSnapshot(of: screen(window: BatchWindow.off), named: "off")
    }

    private func screen(window: TimeInterval) -> some View {
        NavigationStack {
            BatchingSettingsView(window: window, options: BatchWindow.options) { _ in }
        }
    }
}
