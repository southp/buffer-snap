import BufferSnapCore
import Foundation
import Testing

struct AuthSessionTests {
    private let session = AuthSession(
        accessToken: "secret-access",
        refreshToken: "secret-refresh",
        expiresAt: Date(timeIntervalSinceReferenceDate: 0)
    )

    @Test func printingLeavesOutTheTokens() {
        for text in [String(describing: session), String(reflecting: session), "\(session)"] {
            #expect(!text.contains("secret"))
        }
    }

    @Test func surviveEncodingForTheKeychain() throws {
        let decoded = try JSONDecoder().decode(AuthSession.self, from: JSONEncoder().encode(session))

        #expect(decoded == session)
    }

    @Test func inMemoryStoreSavesAndClears() {
        let store = InMemorySessionStore()
        #expect(store.load() == nil)

        store.save(session)
        #expect(store.load() == session)

        store.clear()
        #expect(store.load() == nil)
    }
}
