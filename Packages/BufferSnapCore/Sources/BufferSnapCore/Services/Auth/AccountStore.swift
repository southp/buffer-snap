import Foundation
import Synchronization

/// The signed-in account as last read from Buffer, and when, so it shows after a relaunch with no network.
public struct SavedAccount: Codable, Sendable, Equatable {
    public let account: BufferAccount
    /// When Buffer answered with it, so a relaunch doesn't ask again within the hour.
    public let fetchedAt: Date
    /// Whether Buffer was asked for the picture too. An account saved by 1.1 wasn't, so the next foreground asks again
    /// instead of waiting out the hour without a picture.
    public let askedForAvatar: Bool

    public init(account: BufferAccount, fetchedAt: Date) {
        self.account = account
        self.fetchedAt = fetchedAt
        askedForAvatar = true
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        account = try container.decode(BufferAccount.self, forKey: .account)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        // Missing from what 1.1 saved.
        askedForAvatar = try container.decodeIfPresent(Bool.self, forKey: .askedForAvatar) ?? false
    }
}

/// Keeps the signed-in account between launches. Separate from `SessionStore` on purpose: a change to what's saved
/// here can at worst lose the name until the next fetch, never the session (`docs/decisions/92-account-cache.md`).
///
/// Not `async`, like `SessionStore`: `AppModel` reads it before the first frame.
public protocol AccountStore: Sendable {
    /// The saved account, or `nil` if there's none or it can't be read. Nothing depends on it, so a failed read is
    /// just no name until the next fetch.
    func load() -> SavedAccount?

    /// Replaces the saved account.
    func save(_ account: SavedAccount) throws

    /// Removes the saved account, if there's one.
    func clear() throws
}

/// An `AccountStore` that lasts as long as the process, for tests, previews and the mocked app.
public final class InMemoryAccountStore: AccountStore {
    private let saved: Mutex<SavedAccount?>

    public init(account: SavedAccount? = nil) {
        saved = Mutex(account)
    }

    public func load() -> SavedAccount? {
        saved.withLock { $0 }
    }

    public func save(_ account: SavedAccount) {
        saved.withLock { $0 = account }
    }

    public func clear() {
        saved.withLock { $0 = nil }
    }
}
