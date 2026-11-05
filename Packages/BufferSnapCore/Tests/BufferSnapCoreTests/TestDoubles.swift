import BufferSnapCore
import Foundation

struct TestError: Error {}

/// An `AuthService` that fails as a test says, for testing how models react.
actor StubAuthService: AuthService {
    private let savedSession: Bool
    private var signInError: (any Error)?
    private var signOutError: (any Error)?
    private var tokenError: (any Error)?
    private var onValidAccessToken: (@Sendable () async -> Void)?

    init(
        hasSavedSession: Bool = false,
        signInError: (any Error)? = nil,
        signOutError: (any Error)? = nil,
        tokenError: (any Error)? = nil
    ) {
        savedSession = hasSavedSession
        self.signInError = signInError
        self.signOutError = signOutError
        self.tokenError = tokenError
    }

    nonisolated func hasSavedSession() -> Bool {
        savedSession
    }

    func setTokenError(_ error: (any Error)?) {
        tokenError = error
    }

    /// Runs `action` in the middle of each `validAccessToken()`, so a test can act while one is in flight.
    func setOnValidAccessToken(_ action: @escaping @Sendable () async -> Void) {
        onValidAccessToken = action
    }

    func signIn() async throws {
        if let signInError {
            throw signInError
        }
    }

    func signOut() async throws {
        if let signOutError {
            throw signOutError
        }
    }

    func validAccessToken() async throws -> String {
        await onValidAccessToken?()
        if let tokenError {
            throw tokenError
        }
        return "stub-access-token"
    }

    func accessTokenRejected(_ token: String) {}
}

/// A `CaptureStore` that returns `captures` but fails every write.
struct ReadOnlyCaptureStore: CaptureStore {
    let captures: [Capture]

    func all() async throws -> [Capture] {
        captures
    }

    func add(_ capture: Capture) async throws {
        throw TestError()
    }

    func delete(id: Capture.ID) async throws {
        throw TestError()
    }
}

extension Capture {
    /// A capture made `seconds` after a fixed reference date, so tests can order captures by age.
    static func at(_ seconds: TimeInterval, kind: Kind = .text) -> Capture {
        Capture(kind: kind, createdAt: Date(timeIntervalSinceReferenceDate: seconds))
    }
}

/// A `CaptureStore` that runs `onAdd` in the middle of each `add`, so a test can act while a write is in flight.
actor HookedCaptureStore: CaptureStore {
    let base = InMemoryCaptureStore()
    private var onAdd: (@Sendable () async -> Void)?

    func setOnAdd(_ onAdd: @escaping @Sendable () async -> Void) {
        self.onAdd = onAdd
    }

    func all() async throws -> [Capture] {
        await base.all()
    }

    func add(_ capture: Capture) async throws {
        await onAdd?()
        await base.add(capture)
    }

    func delete(id: Capture.ID) async throws {
        await base.delete(id: id)
    }
}
