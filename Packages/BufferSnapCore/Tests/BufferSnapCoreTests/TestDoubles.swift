import BufferSnapCore
import Foundation

struct TestError: Error {}

/// An `AuthService` whose sign-in always fails.
struct FailingAuthService: AuthService {
    func signIn() async throws {
        throw TestError()
    }
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
