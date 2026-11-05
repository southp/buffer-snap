import CryptoKit
import Foundation

/// The proof that whoever redeems an authorization code is who asked for it. Only `challenge` goes to Buffer until the
/// code is exchanged, so a code stolen on its way back is useless without `verifier`.
public struct PKCE: Sendable, Equatable {
    public let verifier: String

    /// The base64url-encoded SHA-256 hash of `verifier`.
    public var challenge: String {
        Self.base64URLEncoded(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// A pair with a new random verifier.
    public init() {
        self.init(verifier: Self.randomString())
    }

    public init(verifier: String) {
        self.verifier = verifier
    }

    /// 32 random bytes as a URL-safe string of 43 characters. On Apple platforms, the system generator is secure.
    public static func randomString() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URLEncoded(Data(bytes))
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
