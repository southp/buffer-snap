/// Signs the user in to Buffer.
///
/// Only `signIn()` exists for now. Session state, sign-out and real OAuth come with the MVP.
public protocol AuthService: Sendable {
    func signIn() async throws
}

/// An `AuthService` whose sign-in always succeeds, for tests, previews and the mocked app.
public actor MockAuthService: AuthService {
    public init() {}

    public func signIn() {}
}
