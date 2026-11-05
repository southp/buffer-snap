import Foundation
import OSLog
import Security

/// Keeps the session in the Keychain, as one item, so the two tokens and the expiry always change together.
///
/// It sets no access group, so the item lands in the app's own default group, which the widget can't read and which
/// needs no new entitlement (`docs/decisions/43-keychain-session.md`).
public struct KeychainSessionStore: SessionStore {
    /// The Keychain call failed with `status`. `errSecInteractionNotAllowed` means the iPhone hasn't been unlocked
    /// since it started.
    public struct Failure: Error, Equatable {
        public let status: OSStatus
    }

    private let service: String

    public init(service: String = "me.southp.buffersnap.buffer-session") {
        self.service = service
    }

    public func load() throws -> AuthSession? {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw Failure(status: status)
        }
        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            // Only this type writes the item, so this means a format that's gone. Signing in again replaces it.
            Logger.auth.error("Can't read the saved session, so treating it as signed out")
            return nil
        }
    }

    public func save(_ session: AuthSession) throws {
        // Update before adding, not delete and add: a crash in between would lose the only copy of the refresh token.
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(session),
            // After first unlock: #44's background job can read it while the iPhone is locked. This device only: a
            // restored backup must not bring back a single-use refresh token, as using it again revokes the grant.
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
