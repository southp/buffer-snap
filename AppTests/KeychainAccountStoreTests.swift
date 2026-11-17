import BufferSnapCore
import Foundation
import Security
import Testing

/// The real Keychain, which is why this isn't in Core's tests: on macOS, `swift test` has no app and no entitlements.
/// Serialized because every test uses the same item.
@Suite(.serialized)
struct KeychainAccountStoreTests {
    private let service = "me.southp.buffersnap.tests.\(UUID().uuidString)"
    private let saved = SavedAccount(account: .mock, fetchedAt: Date(timeIntervalSinceReferenceDate: 1_000))

    private var store: KeychainAccountStore {
        KeychainAccountStore(service: service)
    }

    @Test func startsEmpty() {
        #expect(store.load() == nil)
    }

    @Test func aSavedAccountComesBack() throws {
        defer { try? store.clear() }

        try store.save(saved)

        #expect(store.load() == saved)
    }

    @Test func savingAgainReplacesTheAccount() throws {
        defer { try? store.clear() }
        let other = SavedAccount(
            account: BufferAccount(name: "Grace Hopper", email: "grace@example.com"),
            fetchedAt: saved.fetchedAt.addingTimeInterval(3600)
        )

        try store.save(saved)
        try store.save(other)

        #expect(store.load() == other)
    }

    @Test func clearingRemovesTheAccountAndCanRepeat() throws {
        try store.save(saved)

        try store.clear()
        try store.clear()

        #expect(store.load() == nil)
    }

    /// The same as the session's item: readable while locked after the first unlock, and never in a backup.
    @Test func itemIsReadableAfterFirstUnlockOnThisDeviceOnly() throws {
        defer { try? store.clear() }
        try store.save(saved)

        let attributes = try savedItemAttributes()

        #expect(
            attributes[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(attributes[kSecAttrAccessGroup as String] as? String != SharedStorage.groupID)
    }

    /// Its own item: saving or clearing the account never touches the session's.
    @Test func theAccountIsNotTheSessionsItem() throws {
        let sessionStore = KeychainSessionStore(service: "\(service).session")
        let session = AuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: saved.fetchedAt)
        defer {
            try? store.clear()
            try? sessionStore.clear()
        }
        try sessionStore.save(session)

        try store.save(saved)
        try store.clear()

        #expect(try sessionStore.load() == session)
    }

    /// A value the store can't decode counts as no account, and the next fetch replaces it.
    @Test func anUnreadableItemCountsAsNoAccount() throws {
        defer { try? store.clear() }
        try store.save(saved)
        let update = [kSecValueData as String: Data("not json".utf8)]
        #expect(SecItemUpdate(itemQuery as CFDictionary, update as CFDictionary) == errSecSuccess)

        #expect(store.load() == nil)

        try store.save(saved)
        #expect(store.load() == saved)
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    private func savedItemAttributes() throws -> [String: Any] {
        var query = itemQuery
        query[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        #expect(status == errSecSuccess)
        return try #require(result as? [String: Any])
    }
}
