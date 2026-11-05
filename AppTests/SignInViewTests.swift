import BufferSnapCore
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

    /// The button is off while a sign-in is under way.
    @Test func signingIn() {
        assertScreenSnapshot(of: SignInView(isSigningIn: true, onSignIn: {}), named: "signingIn")
    }

    /// The user closed Buffer's page, which isn't an error.
    @Test func cancelled() {
        assertScreenSnapshot(of: SignInView(notice: .cancelled, onSignIn: {}), named: "cancelled")
    }

    /// The other notices, all shown as errors. One PNG each, so a message that no longer fits shows up.
    @Test(arguments: [
        (AppModel.SignInNotice.denied, "denied"),
        (.unreachable, "unreachable"),
        (.failed, "failed"),
        (.sessionEnded, "sessionEnded"),
        (.signOutFailed, "signOutFailed"),
    ])
    func errors(notice: AppModel.SignInNotice, name: String) {
        assertScreenSnapshot(of: SignInView(notice: notice, onSignIn: {}), named: name)
    }
}
