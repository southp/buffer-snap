import BufferSnapCore
import Foundation
import Testing

@testable import BufferSnap

@MainActor
struct SystemWebAuthenticatorTests {
    /// Buffer leaves out the refresh token when someone switches account on a page already signed in to another one,
    /// so the page must never share Safari's Buffer sign-in (#85).
    @Test func signInDoesNotShareSafarisLogin() throws {
        let url = try #require(URL(string: "https://auth.buffer.com/auth"))
        let session = SystemWebAuthenticator.makeSession(
            url: url,
            callbackScheme: BufferOAuth.callbackScheme,
            completionHandler: { _, _ in }
        )

        #expect(session.prefersEphemeralWebBrowserSession)
    }
}
