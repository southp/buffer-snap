import BufferSnapCore
import Foundation
import Testing

/// `OAuthAuthService` from tapping sign-in to having a saved session, with a fake web page and a fake server.
@Suite(.timeLimit(.minutes(1)))
struct OAuthSignInTests {
    private let oauth = OAuthFixture()

    /// Every parameter the guide lists, compared with the values registered with Buffer.
    @Test func opensTheAuthorizationPageWithWhatBufferExpects() async throws {
        let web = FakeWebAuthenticator.approving()

        try await oauth.makeService(web: web).signIn()

        let url = try #require(web.openedURLs.first)
        #expect(url.scheme == "https")
        #expect(url.host() == "auth.buffer.com")
        #expect(url.path() == "/auth")
        #expect(url.queryValue("client_id") == "U9uUzfVMfWkpU5P9PiVXL3W1o52xCFevd0B76yas3Br")
        #expect(url.queryValue("redirect_uri") == "https://southp.github.io/buffer-snap/oauth/")
        #expect(url.queryValue("response_type") == "code")
        #expect(url.queryValue("scope") == "ideas:write account:read offline_access")
        #expect(url.queryValue("code_challenge_method") == "S256")
        #expect(url.queryValue("prompt") == "consent")
        #expect(url.queryValue("state")?.isEmpty == false)
        #expect(url.queryValue("code_challenge")?.isEmpty == false)
        #expect(web.openedSchemes == ["buffersnap"])
    }

    /// A public client proves itself with the verifier whose hash went to the authorization page, and has no secret.
    @Test func exchangesTheCodeWithTheMatchingVerifier() async throws {
        let web = FakeWebAuthenticator.approving()

        try await oauth.makeService(web: web).signIn()

        let requests = await oauth.server.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1)
        #expect(request["grant_type"] == "authorization_code")
        #expect(request["code"] == FakeBufferServer.validCode)
        #expect(request["client_id"] == BufferOAuth.clientID)
        #expect(request["redirect_uri"] == BufferOAuth.redirectURI)
        #expect(request["client_secret"] == nil)
        let verifier = try #require(request["code_verifier"])
        #expect(PKCE(verifier: verifier).challenge == web.openedURLs.first?.queryValue("code_challenge"))
    }

    /// The session is saved with an expiry counted from the response, and is then what gets handed out.
    @Test func savesTheSession() async throws {
        let service = oauth.makeService()

        try await service.signIn()

        let saved = try #require(try oauth.store.load())
        #expect(saved.accessToken == "access-1")
        #expect(saved.refreshToken == "refresh-1")
        #expect(saved.expiresAt == oauth.clock.now.addingTimeInterval(3600))
        #expect(service.hasSavedSession())
        #expect(try await service.validAccessToken() == "access-1")
    }

    /// Reusing `state` or the verifier would undo what they protect against.
    @Test func everySignInUsesANewStateAndChallenge() async throws {
        let web = FakeWebAuthenticator.approving()
        let service = oauth.makeService(web: web)

        try await service.signIn()
        try await service.signIn()

        let urls = web.openedURLs
        #expect(urls.count == 2)
        #expect(urls[0].queryValue("state") != urls[1].queryValue("state"))
        #expect(urls[0].queryValue("code_challenge") != urls[1].queryValue("code_challenge"))
    }

    /// A `+` in a form body means a space, so an unencoded one would change the code Buffer receives.
    @Test func formEncodesTheCode() async throws {
        let web = FakeWebAuthenticator { url in
            let state = try #require(url.queryValue("state"))
            return try FakeWebAuthenticator.callback("code=a%2Bb%2Fc%3D&state=\(state)")
        }

        await #expect(throws: AuthError.authorizationFailed) {
            try await oauth.makeService(web: web).signIn()
        }

        let requests = await oauth.server.requests
        let bodies = await oauth.server.rawBodies
        #expect(requests.first?["code"] == "a+b/c=")
        #expect(bodies.first?.contains("code=a%2Bb%2Fc%3D&") == true)
    }

    /// A response this flow didn't start is refused before anything is sent to Buffer, whatever else it says.
    @Test(arguments: [
        "code=stolen&state=wrong",
        "code=stolen",
        "error=access_denied&state=wrong",
    ])
    func refusesAResponseWithTheWrongState(query: String) async throws {
        let web = FakeWebAuthenticator { _ in try FakeWebAuthenticator.callback(query) }

        await #expect(throws: AuthError.authorizationFailed) {
            try await oauth.makeService(web: web).signIn()
        }

        #expect(await oauth.server.requests.isEmpty)
        #expect(try oauth.store.load() == nil)
    }

    @Test(arguments: [
        ("error=access_denied", AuthError.denied),
        ("error=invalid_scope", AuthError.authorizationFailed),
        ("error=invalid_client", AuthError.authorizationFailed),
        ("nothing=here", AuthError.authorizationFailed),
        ("code=", AuthError.authorizationFailed),
    ])
    func reportsWhatTheCallbackSays(query: String, expected: AuthError) async throws {
        let web = FakeWebAuthenticator { url in
            try FakeWebAuthenticator.callback("\(query)&state=\(try #require(url.queryValue("state")))")
        }

        await #expect(throws: expected) {
            try await oauth.makeService(web: web).signIn()
        }

        #expect(await oauth.server.requests.isEmpty)
    }

    @Test func passesOnTheUserClosingThePage() async {
        let web = FakeWebAuthenticator { _ in throw AuthError.cancelled }

        await #expect(throws: AuthError.cancelled) {
            try await oauth.makeService(web: web).signIn()
        }
    }

    @Test(arguments: [
        (FakeBufferServer.Fault.unreachable, AuthError.network),
        (.response(status: 500, body: "oops"), .server),
        (.response(status: 400, body: #"{"error":"invalid_client"}"#), .server),
        (.response(status: 400, body: #"{"error":"invalid_grant"}"#), .authorizationFailed),
        (.response(status: 200, body: "{}"), .server),
    ])
    func aFailedExchangeLeavesNothingSaved(fault: FakeBufferServer.Fault, expected: AuthError) async throws {
        await oauth.server.failNextRequest(fault)

        await #expect(throws: expected) {
            try await oauth.makeService().signIn()
        }

        #expect(try oauth.store.load() == nil)
    }

    /// Without a refresh token the session would end after an hour, so it fails where someone can see why.
    @Test func refusesTokensWithoutARefreshToken() async throws {
        await oauth.server.omit(["refresh_token"])
        let service = oauth.makeService()

        await #expect(throws: AuthError.authorizationFailed) {
            try await service.signIn()
        }

        #expect(try oauth.store.load() == nil)
        await #expect(throws: AuthError.notSignedIn) {
            try await service.validAccessToken()
        }
    }

    /// Not signed in if it can't be remembered: the user finds out now, not at the next launch.
    @Test func failsIfTheSessionCantBeSaved() async {
        oauth.store.fail(saves: true)
        let service = oauth.makeService()

        await #expect(throws: AuthError.storage) {
            try await service.signIn()
        }

        oauth.store.fail()
        await #expect(throws: AuthError.notSignedIn) {
            try await service.validAccessToken()
        }
    }

    @Test func signingOutRemovesTheSession() async throws {
        let service = oauth.makeService()
        try await service.signIn()

        try await service.signOut()

        #expect(try oauth.store.load() == nil)
        #expect(!service.hasSavedSession())
        await #expect(throws: AuthError.notSignedIn) {
            try await service.validAccessToken()
        }
    }

    @Test func reportsFailingToRemoveTheSession() async throws {
        let service = oauth.makeService()
        try await service.signIn()
        oauth.store.fail(clears: true)

        await #expect(throws: AuthError.storage) {
            try await service.signOut()
        }
    }

    /// The list says nothing leaves while signed out, so a session that couldn't be removed can't be sent with.
    @Test func aSessionThatCouldntBeRemovedIsntUsedUntilTheNextLaunch() async throws {
        let service = oauth.makeService()
        try await service.signIn()
        oauth.store.fail(clears: true)
        await #expect(throws: AuthError.storage) {
            try await service.signOut()
        }

        await #expect(throws: AuthError.notSignedIn) {
            try await service.validAccessToken()
        }

        oauth.store.fail()
        _ = try await oauth.makeService().validAccessToken()
    }

    /// Finding no session and failing to look are different: the second must not read as signed out.
    @Test func hasNoSavedSessionIfTheStoreCantBeRead() {
        oauth.store.fail(loads: true)

        #expect(!oauth.makeService().hasSavedSession())
    }
}
