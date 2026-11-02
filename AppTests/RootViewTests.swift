import SwiftUI
import Testing

@testable import BufferSnap

/// The root screen, rendered full-screen to AppTests/__Snapshots__/RootViewTests/.
@MainActor
struct RootViewTests {
    /// The placeholder "BufferSnap" text, centered.
    @Test func screen() {
        assertScreenSnapshot(of: RootView(), named: "placeholder")
    }
}
