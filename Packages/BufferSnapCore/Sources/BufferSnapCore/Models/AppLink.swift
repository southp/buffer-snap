import Foundation

/// A URL the app opens itself at, in its `buffersnap` scheme. The Lock Screen widget opens `buffersnap://capture`.
///
/// Sign-in returns through `buffersnap://oauth`, which `ASWebAuthenticationSession` catches before the app sees it. So
/// that isn't a link: if it ever reaches the app, it's ignored here.
public enum AppLink: Sendable, Equatable {
    /// The capture screen.
    case capture

    /// The scheme the app registers in its `Info.plist`.
    public static let scheme = "buffersnap"

    private static let captureHost = "capture"

    /// The link `url` names, or `nil` if it isn't one of the app's links.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, url.host()?.lowercased() == Self.captureHost else {
            return nil
        }
        self = .capture
    }

    /// The URL that opens this link.
    public var url: URL? {
        switch self {
        case .capture:
            URL(string: "\(Self.scheme)://\(Self.captureHost)")
        }
    }
}
