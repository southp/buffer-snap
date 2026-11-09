import BufferSnapCore
import Foundation
import Testing

/// The test host is the app, so its `Info.plist` is the one that ships.
struct URLSchemeRegistrationTests {
    /// The scheme sign-in comes back through, from Buffer's redirect page.
    @Test func theAppRegistersTheSignInScheme() {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }

        #expect(schemes == [BufferOAuth.callbackScheme])
    }
}
