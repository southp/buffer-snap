/// The Buffer account ideas go to, as far as the app shows it: who it is, never what it can do.
///
/// Buffer's `Account.name` can be `null`, so the app falls back to "this account" and the `person` glyph. Its `email`
/// is never `null` in the schema, but it's optional here so an account without one still shows its name.
public struct BufferAccount: Codable, Sendable, Equatable {
    public let name: String?
    public let email: String?

    public init(name: String?, email: String?) {
        self.name = name
        self.email = email
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

extension BufferAccount {
    /// The made-up account the mocked app is signed in to, for screenshots and UI tests. Never a real person's.
    public static let mock = BufferAccount(name: "Ada Lovelace", email: "ada@example.com")
}
