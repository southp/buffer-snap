import BufferSnapCore
import Foundation
import Testing

/// The test host is the app, so its `Info.plist` is the one that ships.
struct AppLinkRegistrationTests {
    /// Without this, iOS doesn't open the app for the Lock Screen widget's `buffersnap://capture`.
    @Test func theAppRegistersItsScheme() {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }

        #expect(schemes == [AppLink.scheme])
    }
}
