import Foundation
import OSLog

/// Shows Buffer's sign-in page and returns the URL it comes back through. The app implements this with
/// `ASWebAuthenticationSession`, which needs a window, so Core stays free of UI frameworks.
public protocol WebAuthenticator: Sendable {
    /// Throws `AuthError.cancelled` if the user closes the page.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// Buffer's Authorization Code flow with PKCE, as a public client.
public actor OAuthAuthService: AuthService {
    /// Refresh this long before expiry, so a token doesn't run out while a request is in flight.
    private static let expiryMargin: TimeInterval = 60
    /// Buffer's documented lifetime, for a response that leaves it out.
    private static let defaultLifetime: TimeInterval = 3600

    private let web: any WebAuthenticator
    private let client: TokenClient
    private let store: any SessionStore
    private let now: @Sendable () -> Date

    /// What's known of the session. `nil` means look in `store`.
    private var session: AuthSession?

    public init(
        web: any WebAuthenticator,
        transport: any HTTPTransport,
        store: any SessionStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.web = web
        client = TokenClient(transport: transport)
        self.store = store
        self.now = now
    }

    public nonisolated func hasSavedSession() -> Bool {
        do {
            return try store.load() != nil
        } catch {
            Logger.auth.error("Can't read the saved session at launch: \(error, privacy: .public)")
            return false
        }
    }

    public func signIn() async throws {
        let pkce = PKCE()
        let state = PKCE.randomString()
        guard let url = BufferOAuth.authorizationURL(state: state, codeChallenge: pkce.challenge) else {
            throw AuthError.authorizationFailed
        }

        let callback = try await web.authenticate(url: url, callbackScheme: BufferOAuth.callbackScheme)
        let code = try Self.authorizationCode(in: callback, expectedState: state)

        let tokens: TokenResponse
        do {
            tokens = try await client.exchange(code: code, verifier: pkce.verifier)
        } catch is TokenClient.InvalidGrant {
            throw AuthError.authorizationFailed
        }
        // Without one, the session would quietly end in an hour, so fail now, where it's obvious.
        guard let refreshToken = tokens.refreshToken else {
            Logger.auth.error("No refresh token: is offline_access enabled for this app client?")
            throw AuthError.authorizationFailed
        }

        let newSession = AuthSession(
            accessToken: tokens.accessToken,
            refreshToken: refreshToken,
            expiresAt: expiry(of: tokens)
        )
        do {
            try store.save(newSession)
        } catch {
            Logger.auth.error("Can't save the new session: \(error, privacy: .public)")
            throw AuthError.storage
        }
        session = newSession
        Logger.auth.info("Signed in. Token valid until \(newSession.expiresAt, privacy: .public)")
    }

    public func signOut() throws {
        session = nil
        do {
            try store.clear()
        } catch {
            Logger.auth.error("Can't remove the saved session: \(error, privacy: .public)")
            throw AuthError.storage
        }
        Logger.auth.info("Signed out")
    }

    public func validAccessToken() async throws -> String {
        guard let current = try loadSession() else {
            throw AuthError.notSignedIn
        }
        guard now().addingTimeInterval(Self.expiryMargin) < current.expiresAt else {
            throw AuthError.sessionExpired
        }
        return current.accessToken
    }

    public func accessTokenRejected(_ token: String) {
        if let session, session.accessToken == token {
            self.session = AuthSession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                expiresAt: .distantPast
            )
        }
    }

    private func loadSession() throws -> AuthSession? {
        if let session {
            return session
        }
        do {
            session = try store.load()
            return session
        } catch {
            Logger.auth.error("Can't read the saved session: \(error, privacy: .public)")
            throw AuthError.storage
        }
    }

    private func expiry(of tokens: TokenResponse) -> Date {
        now().addingTimeInterval(tokens.expiresIn ?? Self.defaultLifetime)
    }

    /// Checks `state` first, as the guide says: until it matches, nothing else in this URL can be trusted.
    private static func authorizationCode(in callback: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(of name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        guard value(of: "state") == expectedState else {
            Logger.auth.error("The sign-in response's state doesn't match")
            throw AuthError.authorizationFailed
        }
        if let error = value(of: "error") {
            Logger.auth.error("Sign-in error \(error, privacy: .public)")
            throw error == "access_denied" ? AuthError.denied : AuthError.authorizationFailed
        }
        guard let code = value(of: "code"), !code.isEmpty else {
            Logger.auth.error("The sign-in response has no code")
            throw AuthError.authorizationFailed
        }
        return code
    }
}
