import BufferSnapCore
import Foundation
import Synchronization
import Testing

struct NotifyingCaptureStoreTests {
    /// Counts `onChange` calls.
    private final class ChangeCounter: Sendable {
        private let count = Mutex(0)

        var value: Int {
            count.withLock { $0 }
        }

        func increment() {
            count.withLock { $0 += 1 }
        }
    }

    @Test func allPassesThroughWithoutNotifying() async throws {
        let counter = ChangeCounter()
        let seed = [Capture(kind: .text)]
        let store = NotifyingCaptureStore(base: InMemoryCaptureStore(seed: seed), onChange: counter.increment)

        #expect(try await store.all() == seed)
        #expect(counter.value == 0)
    }

    @Test func addWritesThenNotifies() async throws {
        let counter = ChangeCounter()
        let base = InMemoryCaptureStore()
        let store = NotifyingCaptureStore(base: base, onChange: counter.increment)
        let capture = Capture(kind: .photo)

        try await store.add(capture)

        #expect(try await base.all() == [capture])
        #expect(counter.value == 1)
    }

    @Test func deleteWritesThenNotifies() async throws {
        let counter = ChangeCounter()
        let capture = Capture(kind: .photo)
        let base = InMemoryCaptureStore(seed: [capture])
        let store = NotifyingCaptureStore(base: base, onChange: counter.increment)

        try await store.delete(id: capture.id)

        #expect(try await base.all().isEmpty)
        #expect(counter.value == 1)
    }

    @Test func setStatusWritesThenNotifies() async throws {
        let counter = ChangeCounter()
        let capture = Capture(kind: .text)
        let base = InMemoryCaptureStore(seed: [capture])
        let store = NotifyingCaptureStore(base: base, onChange: counter.increment)

        try await store.setStatus(.submitted, ids: [capture.id])

        #expect(try await base.all().map(\.status) == [.submitted])
        #expect(counter.value == 1)
    }

    @Test func assignBatchesWritesThenNotifies() async throws {
        let counter = ChangeCounter()
        let capture = Capture(kind: .text)
        let base = InMemoryCaptureStore(seed: [capture])
        let store = NotifyingCaptureStore(base: base, onChange: counter.increment)

        try await store.assignBatches([capture.id: capture.id])

        #expect(try await base.all().map(\.batchID) == [capture.id])
        #expect(counter.value == 1)
    }

    @Test func failedWritesDoNotNotify() async throws {
        let counter = ChangeCounter()
        let capture = Capture(kind: .photo)
        let store = NotifyingCaptureStore(base: ReadOnlyCaptureStore(captures: [capture]), onChange: counter.increment)

        await #expect(throws: TestError.self) {
            try await store.add(Capture(kind: .text))
        }
        await #expect(throws: TestError.self) {
            try await store.delete(id: capture.id)
        }
        await #expect(throws: TestError.self) {
            try await store.setStatus(.failed, ids: [capture.id])
        }
        await #expect(throws: TestError.self) {
            try await store.assignBatches([capture.id: capture.id])
        }
        #expect(counter.value == 0)
    }
}
