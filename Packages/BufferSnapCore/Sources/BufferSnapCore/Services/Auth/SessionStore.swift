import Synchronization

/// Keeps the signed-in session between launches.
///
/// Not `async` like the other services: `AppModel` needs an answer before the first frame, so a store has to be able
/// to answer right away.
public protocol SessionStore: Sendable {
    /// The saved session, or `nil` if there's none. Throwing means the store couldn't tell, which is not the same as
    /// having no session: nobody may treat it as being signed out.
    func load() throws -> AuthSession?

    /// Replaces the saved session in one step, so a crash leaves either the old session or the new one.
    func save(_ session: AuthSession) throws

    /// Removes the saved session, if there's one.
    func clear() throws
}

/// A `SessionStore` that lasts as long as the process, for tests and previews.
public final class InMemorySessionStore: SessionStore {
    private let session: Mutex<AuthSession?>

    public init(session: AuthSession? = nil) {
        self.session = Mutex(session)
    }

    public func load() -> AuthSession? {
        session.withLock { $0 }
    }

    public func save(_ session: AuthSession) {
        self.session.withLock { $0 = session }
    }

    public func clear() {
        session.withLock { $0 = nil }
    }
}
