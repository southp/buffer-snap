import Foundation

/// What the app holds after sign-in. The tokens are credentials for someone's Buffer account, so `description` leaves
/// them out, which keeps them out of logs and test output.
public struct AuthSession: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public let accessToken: String
    public let refreshToken: String
    /// When Buffer stops accepting `accessToken`.
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public var description: String {
        "AuthSession(expiresAt: \(expiresAt))"
    }

    public var debugDescription: String {
        description
    }
}
