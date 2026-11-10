import Foundation
import OSLog

/// Shows Buffer's sign-in page and returns the URL it comes back through. The app implements this with
/// `ASWebAuthenticationSession`, which needs a window, so Core stays free of UI frameworks.
public protocol WebAuthenticator: Sendable {
    /// Throws `AuthError.cancelled` if the user closes the page.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// Buffer's Authorization Code flow with PKCE, as a public client.
///
/// **Refresh tokens are single-use, and using one twice revokes every token for the grant.** This actor is the one
/// place that refreshes, so:
/// - All callers during a refresh wait for the same request.
/// - The refresh runs in its own task, so a cancelled caller can't abandon a request Buffer may already have acted on.
/// - The new session is saved before any caller gets its access token.
/// - If saving fails, the new session stays in memory, as the saved refresh token is now dead. No caller gets a token
///   until a save works.
/// - Only `invalid_grant` ends a session. Failing to reach Buffer leaves it as it was, to try again later.
///
/// What a crash or a lost response costs: `docs/decisions/43-single-use-refresh-tokens.md`.
public actor OAuthAuthService: AuthService {
    /// A refresh was overtaken by a sign-out or a new sign-in, so its result belongs to a session that's gone.
    private struct RefreshSuperseded: Error {}

    /// Refresh this long before expiry, so a token doesn't run out while a request is in flight.
    private static let expiryMargin: TimeInterval = 60
    /// Buffer's documented lifetime, for a response that leaves it out.
    private static let defaultLifetime: TimeInterval = 3600

    private let web: any WebAuthenticator
    private let client: TokenClient
    private let store: any SessionStore
    private let now: @Sendable () -> Date

    /// What's known of the session, which is ahead of `store` while `isSessionUnsaved`. `nil` means look in `store`.
    private var session: AuthSession?
    private var isSessionUnsaved = false
    /// A sign-out couldn't remove the saved session. The person asked to be signed out and the list says nothing leaves
    /// now, so it isn't used again until the next launch, which the list warns about.
    private var ignoresSavedSession = false
    private var refreshTask: Task<AuthSession, any Error>?
    /// Changes when a sign-out or sign-in replaces the session, so a refresh still in flight can tell it's stale.
    private var sessionGeneration = 0

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
            let granted = tokens.scope ?? "none listed"
            Logger.auth.error("No refresh token: Buffer granted [\(granted, privacy: .public)] without offline_access")
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
        replaceSession(with: newSession)
        Logger.auth.info("Signed in. Token valid until \(newSession.expiresAt, privacy: .public)")
    }

    public func signOut() throws {
        replaceSession(with: nil)
        do {
            try store.clear()
            ignoresSavedSession = false
        } catch {
            ignoresSavedSession = true
            Logger.auth.error("Can't remove the saved session: \(error, privacy: .public)")
            throw AuthError.storage
        }
        Logger.auth.info("Signed out")
    }

    public func validAccessToken() async throws -> String {
        if let refreshTask {
            return try await accessToken(from: refreshTask)
        }
        guard let current = try loadSession() else {
            throw AuthError.notSignedIn
        }
        try saveSessionIfNeeded()
        if now().addingTimeInterval(Self.expiryMargin) < current.expiresAt {
            return current.accessToken
        }

        let generation = sessionGeneration
        let task = Task {
            try await self.refresh(current, generation: generation)
        }
        refreshTask = task
        return try await accessToken(from: task)
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

    private func accessToken(from task: Task<AuthSession, any Error>) async throws -> String {
        do {
            return try await task.value.accessToken
        } catch is RefreshSuperseded {
            return try await validAccessToken()
        }
    }

    /// Everything from the response onward happens without suspending, so no caller can see a half-finished result.
    private func refresh(_ current: AuthSession, generation: Int) async throws -> AuthSession {
        let result: Result<TokenResponse, any Error>
        do {
            result = .success(try await client.refresh(refreshToken: current.refreshToken))
        } catch {
            result = .failure(error)
        }

        guard generation == sessionGeneration else {
            throw RefreshSuperseded()
        }
        refreshTask = nil

        switch result {
        case .success(let tokens):
            let newSession = AuthSession(
                accessToken: tokens.accessToken,
                // Buffer says it always sends a new one. If it ever doesn't, then the old one is all there is.
                refreshToken: tokens.refreshToken ?? current.refreshToken,
                expiresAt: expiry(of: tokens)
            )
            session = newSession
            isSessionUnsaved = true
            try saveSessionIfNeeded()
            Logger.auth.info("Refreshed. Token valid until \(newSession.expiresAt, privacy: .public)")
            return newSession
        case .failure(is TokenClient.InvalidGrant):
            Logger.auth.notice("Buffer rejected the refresh token, so the session has ended")
            replaceSession(with: nil)
            do {
                try store.clear()
            } catch {
                // The next attempt finds the same dead token, gets the same rejection and tries this again.
                Logger.auth.error("Can't remove the rejected session: \(error, privacy: .public)")
            }
            throw AuthError.sessionExpired
        case .failure(let error):
            throw error
        }
    }

    private func loadSession() throws -> AuthSession? {
        if let session {
            return session
        }
        guard !ignoresSavedSession else {
            return nil
        }
        do {
            session = try store.load()
            return session
        } catch {
            Logger.auth.error("Can't read the saved session: \(error, privacy: .public)")
            throw AuthError.storage
        }
    }

    private func saveSessionIfNeeded() throws {
        guard isSessionUnsaved, let session else {
            return
        }
        do {
            try store.save(session)
            isSessionUnsaved = false
        } catch {
            Logger.auth.error("Can't save the refreshed session: \(error, privacy: .public)")
            throw AuthError.storage
        }
    }

    /// Makes `newSession` current, and leaves behind whatever a refresh in flight is about to report.
    private func replaceSession(with newSession: AuthSession?) {
        session = newSession
        isSessionUnsaved = false
        refreshTask = nil
        sessionGeneration += 1
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
