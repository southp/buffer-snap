import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The color scheme each appearance asks the window for.
struct AppearanceColorSchemeTests {
    /// System prefers none, so iOS decides; Light and Dark prefer their own.
    @Test func eachChoicePrefersItsColorScheme() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }
}
