import Foundation
import Testing

@testable import BufferSnapCore

struct AppVersionTests {
    @Test func readsTheVersionAndBuildFromInfoPlistValues() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.1", "CFBundleVersion": "42"])

        #expect(version == AppVersion(version: "1.1", build: "42"))
    }

    @Test func showsAQuestionMarkForWhatIsMissing() {
        #expect(AppVersion(infoDictionary: ["CFBundleVersion": "42"]) == AppVersion(version: "?", build: "42"))
        #expect(AppVersion(infoDictionary: nil) == AppVersion(version: "?", build: "?"))
    }
}
