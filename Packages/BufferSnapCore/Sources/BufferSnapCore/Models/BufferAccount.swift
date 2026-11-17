import Foundation

/// The Buffer account ideas go to, as far as the app shows it: who it is, never what it can do.
///
/// Buffer's `Account.name` can be `null`, so the app falls back to "this account" and the `person` glyph. Its `email`
/// is never `null` in the schema, but it's optional here so an account without one still shows its name.
public struct BufferAccount: Codable, Sendable, Equatable {
    public let name: String?
    public let email: String?
    /// Where the account's profile picture is, only if it's on Buffer's own bucket (`avatarHost`). It holds the
    /// account's ID, so it's never logged.
    public let avatarURL: URL?

    /// `avatarURL` is dropped unless it's one the app may load (`isAllowedAvatarURL(_:)`).
    public init(name: String?, email: String?, avatarURL: URL? = nil) {
        self.name = name
        self.email = email
        self.avatarURL = avatarURL.flatMap { Self.isAllowedAvatarURL($0) ? $0 : nil }
    }

    /// Decoded through `init`, so a saved account can't bring back a picture from anywhere else.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decodeIfPresent(String.self, forKey: .name),
            email: try container.decodeIfPresent(String.self, forKey: .email),
            avatarURL: try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        )
    }

    /// The name, unless it's missing or only spaces.
    public var displayName: String? {
        guard let name else {
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Up to two letters for the toolbar's chip: the first letter of the name's first word and of its last, as in
    /// "AL" for "Ada Lovelace". `nil` without a name, so the chip shows the `person` glyph instead.
    public var initials: String? {
        let words = displayName?.split(whereSeparator: \.isWhitespace) ?? []
        guard let first = words.first?.first else {
            return nil
        }
        guard words.count > 1, let last = words.last?.first else {
            return String(first).uppercased()
        }
        return (String(first) + String(last)).uppercased()
    }
}

// MARK: - The profile picture

extension BufferAccount {
    /// The one host the app loads a profile picture from: Buffer's own bucket on Amazon S3, where its `Account.avatar`
    /// points. Nothing else is ever requested (#108, `docs/decisions/108-avatar-from-buffers-s3.md`).
    public static let avatarHost = "buffer-account-avatars-bucket.s3.amazonaws.com"

    /// Whether the app may load `url`: `https`, on exactly `avatarHost`, with no port and no user. A lookalike such
    /// as `buffer-account-avatars-bucket.s3.amazonaws.com.evil.example`, another bucket or a percent-encoded host
    /// isn't.
    public static func isAllowedAvatarURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.scheme == "https"
            && components.percentEncodedHost == avatarHost
            && components.port == nil
            && components.user == nil
            && components.password == nil
    }

    /// Buffer's `Account.avatar` as a URL the app may load, or `nil` for anything else, so the chip shows initials.
    public static func avatarURL(from avatar: String?) -> URL? {
        guard let avatar, let url = URL(string: avatar), isAllowedAvatarURL(url) else {
            return nil
        }
        return url
    }
}

extension BufferAccount {
    /// The made-up account the mocked app is signed in to, for screenshots and UI tests. Never a real person's, and its
    /// picture is made up too: the mocked app never asks for it over the network.
    public static let mock = BufferAccount(
        name: "Ada Lovelace",
        email: "ada@example.com",
        avatarURL: URL(string: "https://\(avatarHost)/example/ada-lovelace.png")
    )
}
