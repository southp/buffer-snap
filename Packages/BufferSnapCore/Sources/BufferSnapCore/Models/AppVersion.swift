import Foundation

/// The app's version and build, which people quote when they report a problem: the account menu shows
/// "BufSnap 1.1 (42)".
public struct AppVersion: Equatable, Sendable {
    /// The version people see in the App Store, `CFBundleShortVersionString` (e.g. "1.1").
    public let version: String
    /// The build number, `CFBundleVersion` (e.g. "42"), which tells TestFlight builds of one version apart.
    public let build: String

    public init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    /// Reads both from a bundle's Info.plist, e.g. `Bundle.main.infoDictionary`. A missing one reads "?", so the
    /// other still shows.
    public init(infoDictionary: [String: Any]?) {
        self.init(
            version: infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            build: infoDictionary?["CFBundleVersion"] as? String ?? "?"
        )
    }
}
