import BufferSnapCore
import Foundation
import Testing

// Exercised through the protocol, the way models use it.
struct InMemoryCaptureStoreTests {
    @Test func startsWithSeed() async throws {
        let seed = [Capture(kind: .text, text: "a"), Capture(kind: .photo)]
        let store: any CaptureStore = InMemoryCaptureStore(seed: seed)

        #expect(try await store.all() == seed)
    }

    @Test func addThenAllReturnsCapture() async throws {
        let store: any CaptureStore = InMemoryCaptureStore()
        let capture = Capture(kind: .photo)

        try await store.add(capture)

        #expect(try await store.all() == [capture])
    }

    @Test func setStatusChangesOnlyTheNamedCaptures() async throws {
        let failed = Capture.at(1)
        let waiting = Capture.at(2)
        let store: any CaptureStore = InMemoryCaptureStore(seed: [failed, waiting])

        try await store.setStatus(.failed, ids: [failed.id, UUID()])

        #expect(try await store.all().map(\.status) == [.failed, .pending])
    }

    @Test func deleteRemovesOnlyMatchingCapture() async throws {
        let kept = Capture(kind: .text)
        let deleted = Capture(kind: .photo)
        let store: any CaptureStore = InMemoryCaptureStore(seed: [kept, deleted])

        try await store.delete(id: deleted.id)

        #expect(try await store.all() == [kept])
    }

    @Test func deleteUnknownIDDoesNothing() async throws {
        let seed = [Capture(kind: .text)]
        let store: any CaptureStore = InMemoryCaptureStore(seed: seed)

        try await store.delete(id: UUID())

        #expect(try await store.all() == seed)
    }
}
