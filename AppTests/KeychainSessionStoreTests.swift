import BufferSnapCore
import Foundation
import Security
import Testing

/// The real Keychain, which is why this isn't in Core's tests: on macOS, `swift test` has no app and no entitlements.
/// Serialized because every test uses the same item.
@Suite(.serialized)
struct KeychainSessionStoreTests {
    private let service = "me.southp.buffersnap.tests.\(UUID().uuidString)"
    private let session = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        expiresAt: Date(timeIntervalSinceReferenceDate: 1_000)
    )

    private var store: KeychainSessionStore {
        KeychainSessionStore(service: service)
    }

    @Test func startsEmpty() throws {
        #expect(try store.load() == nil)
    }

    @Test func aSavedSessionComesBack() throws {
        defer { try? store.clear() }

        try store.save(session)

        #expect(try store.load() == session)
    }

    /// A second save has to replace the item in place, or the old, single-use refresh token would still be there.
    @Test func savingAgainReplacesTheSession() throws {
        defer { try? store.clear() }
        let rotated = AuthSession(accessToken: "access2", refreshToken: "refresh2", expiresAt: session.expiresAt)

        try store.save(session)
        try store.save(rotated)

        #expect(try store.load() == rotated)
    }

    @Test func clearingRemovesTheSessionAndCanRepeat() throws {
        try store.save(session)

        try store.clear()
        try store.clear()

        #expect(try store.load() == nil)
    }

    /// #44's background job has to read the item while the iPhone is locked, and a backup must never carry it.
    @Test func itemIsReadableAfterFirstUnlockOnThisDeviceOnly() throws {
        defer { try? store.clear() }
        try store.save(session)

        let attributes = try savedItemAttributes()

        #expect(
            attributes[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    /// The default access group: the app's own, not the App Group the widget shares.
    @Test func itemIsNotInTheAppGroup() throws {
        defer { try? store.clear() }
        try store.save(session)

        let attributes = try savedItemAttributes()

        #expect(attributes[kSecAttrAccessGroup as String] as? String != SharedStorage.groupID)
    }

    /// A value the store can't decode counts as signed out, and signing in replaces it.
    @Test func anUnreadableItemCountsAsNoSession() throws {
        defer { try? store.clear() }
        try store.save(session)
        let update = [kSecValueData as String: Data("not json".utf8)]
        #expect(SecItemUpdate(itemQuery as CFDictionary, update as CFDictionary) == errSecSuccess)

        #expect(try store.load() == nil)

        try store.save(session)
        #expect(try store.load() == session)
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
