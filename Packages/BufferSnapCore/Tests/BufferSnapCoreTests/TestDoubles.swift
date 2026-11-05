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

/// An `AuthService` whose `signIn()` a test can fail once or hold open.
actor ControllableSignInAuthService: AuthService {
    private(set) var signInCount = 0
    private var nextError: (any Error)?
    private var isHolding = false
    private var held: CheckedContinuation<Void, Never>?

    nonisolated func hasSavedSession() -> Bool {
        false
    }

    func failNextSignIn(with error: any Error) {
        nextError = error
    }

    func holdNextSignIn() {
        isHolding = true
    }

    func releaseSignIn() {
        held?.resume()
        held = nil
    }

    func waitForHeldSignIn() async {
        while held == nil {
            await Task.yield()
        }
    }

    func signIn() async throws {
        signInCount += 1
        if isHolding {
            isHolding = false
            await withCheckedContinuation { held = $0 }
        }
        if let error = nextError {
            nextError = nil
            throw error
        }
    }

    func signOut() {}

    func validAccessToken() -> String {
        "stub-access-token"
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

    func setStatus(_ status: Capture.Status, ids: Set<Capture.ID>) async throws {
        throw TestError()
    }

    func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws {
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

    func setStatus(_ status: Capture.Status, ids: Set<Capture.ID>) async throws {
        await base.setStatus(status, ids: ids)
    }

    func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws {
        await base.assignBatches(batchIDs)
    }
}
