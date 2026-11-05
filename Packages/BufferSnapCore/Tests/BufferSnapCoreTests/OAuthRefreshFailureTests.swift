import BufferSnapCore
import Foundation
import Testing

/// `OAuthAuthService` when a refresh goes wrong: what ends a session, what doesn't, and what a crash costs.
@Suite(.timeLimit(.minutes(1)))
struct OAuthRefreshFailureTests {
    private let oauth = OAuthFixture()

    // MARK: Failing without signing out

    @Test func aNetworkFailureKeepsTheSession() async throws {
        let service = try await oauth.makeRestoredService()
        let saved = try oauth.store.load()
        await oauth.server.failNextRequest(.unreachable)

        await #expect(throws: AuthError.network) {
            try await service.validAccessToken()
        }

        #expect(try oauth.store.load() == saved)
        #expect(service.hasSavedSession())
        #expect(try await service.validAccessToken() == "access-2")
        #expect(await oauth.server.isGrantRevoked == false)
    }

    /// Only `invalid_grant` means the token is dead. These don't, so none of them may end the session.
    @Test(arguments: [
        FakeBufferServer.Fault.response(status: 500, body: "Internal Server Error"),
        .response(status: 503, body: ""),
        .response(status: 429, body: #"{"error":"rate_limited"}"#),
        .response(status: 401, body: #"{"error":"invalid_client"}"#),
        .response(status: 400, body: #"{"error":"invalid_request"}"#),
        .response(status: 200, body: "{}"),
        .response(status: 200, body: "<html>"),
    ])
    func anythingButARejectionKeepsTheSession(fault: FakeBufferServer.Fault) async throws {
        let service = try await oauth.makeRestoredService()
        let saved = try oauth.store.load()
        await oauth.server.failNextRequest(fault)

        await #expect(throws: AuthError.server) {
            try await service.validAccessToken()
        }

        #expect(try oauth.store.load() == saved)
        #expect(try await service.validAccessToken() == "access-2")
    }

    /// Being unable to read the store isn't the same as having no session, as when the iPhone hasn't been unlocked
    /// since it restarted. It must neither sign out nor overwrite anything.
    @Test func anUnreadableStoreKeepsTheSession() async throws {
        let service = try await oauth.makeRestoredService(lifetime: 3000)
        oauth.store.fail(loads: true)

        await #expect(throws: AuthError.storage) {
            try await service.validAccessToken()
        }

        oauth.store.fail()
        #expect(try await service.validAccessToken() == "access-1")
    }

    // MARK: A real rejection

    @Test func aRejectionEndsTheSession() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.revokeGrant()

        await #expect(throws: AuthError.sessionExpired) {
            try await service.validAccessToken()
        }

        #expect(try oauth.store.load() == nil)
        #expect(!service.hasSavedSession())
        await #expect(throws: AuthError.notSignedIn) {
            try await service.validAccessToken()
        }
    }

    /// The Keychain is unavailable when the rejection comes, so the dead token stays there. It's only rejected again.
    @Test func aRejectionThatCantClearTheStoreEndsTheSessionAnyway() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.revokeGrant()
        oauth.store.fail(clears: true)

        await #expect(throws: AuthError.sessionExpired) {
            try await service.validAccessToken()
        }

        oauth.store.fail()
        await #expect(throws: AuthError.sessionExpired) {
            try await service.validAccessToken()
        }
        #expect(try oauth.store.load() == nil)
    }

    /// The crash the design can't prevent: Buffer rotates the token, and the app dies before saving the response. The
    /// next launch sends the old token, Buffer revokes the grant, and the user signs in again. Nothing worse happens.
    @Test func aCrashBeforeSavingTheResponseEndsInSigningInAgain() async throws {
        let crashed = try await oauth.makeRestoredService()
        await oauth.server.failNextRequest(.responseLost)
        _ = try? await crashed.validAccessToken()
        #expect(try oauth.store.load()?.refreshToken == "refresh-1")

        let relaunched = oauth.makeService()
        #expect(relaunched.hasSavedSession())
        await #expect(throws: AuthError.sessionExpired) {
            try await relaunched.validAccessToken()
        }
        #expect(await oauth.server.isGrantRevoked)
        #expect(try oauth.store.load() == nil)
    }

    /// The same without a crash. The app can't tell a lost response from an unreachable server, so it keeps the
    /// session, and retrying is what finds out.
    @Test func aLostResponseKeepsTheSessionUntilTheRetryIsRejected() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.failNextRequest(.responseLost)

        await #expect(throws: AuthError.network) {
            try await service.validAccessToken()
        }
        #expect(service.hasSavedSession())

        await #expect(throws: AuthError.sessionExpired) {
            try await service.validAccessToken()
        }
    }

    // MARK: Sign-out and sign-in during a refresh

    /// A response arriving after sign-out must not bring the session back, in memory or in the Keychain.
    @Test func signingOutDuringARefreshStaysSignedOut() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.holdNextResponse()

        let caller = Task {
            try await service.validAccessToken()
        }
        await oauth.server.waitForHeldRequest()
        try await service.signOut()
        await oauth.server.releaseResponse()

        await #expect(throws: AuthError.notSignedIn) {
            try await caller.value
        }
        #expect(try oauth.store.load() == nil)
        await #expect(throws: AuthError.notSignedIn) {
            try await service.validAccessToken()
        }
    }

    /// An old session's rejection arriving after a new sign-in must not end the new session, and whoever was waiting
    /// gets the new session's token.
    @Test func anOldRefreshsRejectionLeavesANewSessionAlone() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.holdNextResponse()

        let caller = Task {
            try await service.validAccessToken()
        }
        await oauth.server.waitForHeldRequest()
        try await service.signIn()
        await oauth.server.failNextRequest(.response(status: 400, body: #"{"error":"invalid_grant"}"#))
        await oauth.server.releaseResponse()

        #expect(try await caller.value == "access-2")
        #expect(try oauth.store.load()?.accessToken == "access-2")
    }

    // MARK: A token the API rejected

    /// A token that's fine by our clock but not by Buffer's API, as after a clock change. The next call refreshes.
    @Test func aRejectedTokenIsRefreshedOnTheNextCall() async throws {
        let service = try await oauth.makeRestoredService(lifetime: 3000)
        let token = try await service.validAccessToken()

        await service.accessTokenRejected(token)

        #expect(try await service.validAccessToken() == "access-2")
    }

    /// Several requests can fail with one token. Only the first report counts, so they cause one refresh, not one each.
    @Test func reportingAnOldTokenDoesNothing() async throws {
        let service = try await oauth.makeRestoredService(lifetime: 3000)
        let token = try await service.validAccessToken()
        await service.accessTokenRejected(token)
        _ = try await service.validAccessToken()

        await service.accessTokenRejected(token)
        _ = try await service.validAccessToken()

        #expect(await oauth.refreshRequests().count == 1)
    }

    /// How #44 learns that the user revoked the app in Buffer's settings: a 401, then a rejected refresh.
    @Test func aRevokedSessionSurfacesThroughTheRefresh() async throws {
        let service = try await oauth.makeRestoredService(lifetime: 3000)
        let token = try await service.validAccessToken()
        await oauth.server.revokeGrant()

        await service.accessTokenRejected(token)

        await #expect(throws: AuthError.sessionExpired) {
            try await service.validAccessToken()
        }
    }
}
