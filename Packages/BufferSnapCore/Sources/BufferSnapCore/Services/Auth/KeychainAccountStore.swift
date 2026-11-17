import Foundation
import OSLog
import Security

/// Keeps the signed-in account's name and email in the Keychain, as its own item, next to the session's but never in
/// it (`docs/decisions/92-account-cache.md`).
///
/// The same accessibility and access group as `KeychainSessionStore`: readable after first unlock, on this device only,
/// in the app's own group, which the widget can't read. It's the same code on purpose rather than shared with that
/// store, so this feature can't change how the session is saved.
public struct KeychainAccountStore: AccountStore {
    /// The Keychain call failed with `status`.
    public struct Failure: Error, Equatable {
        public let status: OSStatus
    }

    private let service: String

    public init(service: String = "me.southp.buffersnap.buffer-account") {
        self.service = service
    }

    public func load() -> SavedAccount? {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            Logger.auth.error("Can't read the saved account: status \(status, privacy: .public)")
            return nil
        }
        do {
            return try JSONDecoder().decode(SavedAccount.self, from: data)
        } catch {
            // A format that's gone: the next fetch replaces it.
            Logger.auth.error("Can't decode the saved account, so showing none until the next fetch")
            return nil
        }
    }

    public func save(_ account: SavedAccount) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(account),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(itemQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw Failure(status: updateStatus)
        }
        let addStatus = SecItemAdd(itemQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Failure(status: addStatus)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure(status: status)
        }
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "buffer",
        ]
    }
}
