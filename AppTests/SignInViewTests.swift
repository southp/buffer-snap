import SwiftUI
import Testing

@testable import BufferSnap

/// The sign-in screen, rendered full-screen to AppTests/__Snapshots__/SignInViewTests/.
@MainActor
struct SignInViewTests {
    /// The app's name, the tagline and the authenticate button.
    @Test func screen() {
        assertScreenSnapshot(of: SignInView(onSignIn: {}), named: "signedOut")
    }
}
