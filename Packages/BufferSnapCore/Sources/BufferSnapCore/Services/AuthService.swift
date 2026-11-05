/// Signs the user in to Buffer and hands out access tokens.
///
/// There must be one instance per process, and only the app's process may have one: refresh tokens are single-use, so
/// two refreshers would revoke the session. `BufferSnapApp` builds it, and everything else gets it through
/// `AppEnvironment`.
public protocol AuthService: Sendable {
    /// Whether a session was saved by an earlier launch. Not `async`, so the first frame can already show the right
    /// screen. It doesn't check with Buffer: `validAccessToken()` does.
    func hasSavedSession() -> Bool

    /// Runs the whole sign-in, and saves the session before returning. Throws an `AuthError`.
    func signIn() async throws

    /// Forgets the session, here and in storage. Throws `AuthError.storage` if it can't remove the saved one.
    func signOut() async throws

    /// An access token Buffer should accept right now, refreshing it first if needed. Safe to call from anywhere at any
    /// time, including a background task and many callers at once, and cancelling a caller doesn't stop a refresh.
    ///
    /// Throws an `AuthError`. `requiresSignIn` tells apart losing the session from a failure worth retrying later.
    func validAccessToken() async throws -> String

    /// Reports a 401 from Buffer's API for `token`, so the next `validAccessToken()` refreshes even if the token hasn't
    /// expired by our clock. If access was revoked, that refresh is what finds out, and it throws
    /// `AuthError.sessionExpired`. Does nothing for a token that's already been replaced.
    func accessTokenRejected(_ token: String) async
}

/// Why signing in or getting an access token failed. Tokens and codes never appear in these.
public enum AuthError: Error, Equatable, Sendable {
    /// The user closed Buffer's sign-in page.
    case cancelled
    /// The user declined on Buffer's consent page.
    case denied
    /// Sign-in can't be completed: Buffer reported an error, or the response didn't come from a flow this app started.
    case authorizationFailed
    /// Couldn't reach Buffer. Any session is untouched.
    case network
    /// Buffer answered, but with neither tokens nor a rejection, such as a 500 or a 429. Any session is untouched.
    case server
    /// Couldn't read or write the Keychain. Any session is untouched.
    case storage
    /// Buffer rejected the refresh token, so the session is gone and the user has to sign in again.
    case sessionExpired
    /// There's no session.
    case notSignedIn

    /// Whether only signing in again can fix this. Anything else may work if tried again later.
    public var requiresSignIn: Bool {
        self == .sessionExpired || self == .notSignedIn
    }
}

/// An `AuthService` whose sign-in always succeeds, for tests, previews and the mocked app.
public actor MockAuthService: AuthService {
    private let startsWithSavedSession: Bool
    private var isSignedIn: Bool

    public init(hasSavedSession: Bool = false) {
        startsWithSavedSession = hasSavedSession
        isSignedIn = hasSavedSession
    }

    public nonisolated func hasSavedSession() -> Bool {
        startsWithSavedSession
    }

    public func signIn() {
        isSignedIn = true
    }

    public func signOut() {
        isSignedIn = false
    }

    public func validAccessToken() throws -> String {
        guard isSignedIn else {
            throw AuthError.notSignedIn
        }
        return "mock-access-token"
    }

    public func accessTokenRejected(_ token: String) {}
}
