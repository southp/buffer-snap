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

    /// Failed includes what's held at sign-in, and pending includes what's open: only what reached Buffer goes.
    @Test func deleteSubmittedRemovesOnlyWhatWasSubmitted() async throws {
        let store: any CaptureStore = InMemoryCaptureStore(seed: [
            Capture(kind: .text, status: .submitted, text: "Sent"),
            Capture(kind: .photo, status: .submitted),
            Capture(kind: .text, status: .pending, text: "Waiting"),
            Capture(kind: .text, status: .failed, text: "Refused", failure: .refused),
            Capture(kind: .text, status: .failed, text: "Held", failure: .heldAtSignIn),
        ])

        try await store.deleteSubmitted()

        #expect(try await store.all().compactMap(\.text) == ["Waiting", "Refused", "Held"])
    }

    /// `setStatus` skips what's gone, so a send saved after the clear can't add a cleared capture back.
    @Test func aStatusWrittenAfterDeleteSubmittedCannotBringACaptureBack() async throws {
        let sent = Capture(kind: .text, status: .submitted)
        let store: any CaptureStore = InMemoryCaptureStore(seed: [sent])

        try await store.deleteSubmitted()
        try await store.setStatus(.submitted, ids: [sent.id])

        #expect(try await store.all().isEmpty)
    }

    @Test func aFailureKeepsItsReasonUntilTheStatusChanges() async throws {
        let capture = Capture.at(1)
        let store: any CaptureStore = InMemoryCaptureStore(seed: [capture])

        try await store.setStatus(.failed, failure: .refused, ids: [capture.id])
        #expect(try await store.all().map(\.failure) == [.refused])

        try await store.setStatus(.pending, failure: .refused, ids: [capture.id])
        #expect(try await store.all().map(\.failure) == [nil])
    }

    @Test func deleteRemovesOnlyMatchingCapture() async throws {
        let kept = Capture(kind: .text)
        let deleted = Capture(kind: .photo)
        let store: any CaptureStore = InMemoryCaptureStore(seed: [kept, deleted])

        try await store.delete(id: deleted.id)

        #expect(try await store.all() == [kept])
    }

    @Test func assignBatchesOnlyFillsInWhatsMissing() async throws {
        let open = Capture.at(1)
        let closed = Capture(kind: .text, batchID: UUID())
        let store: any CaptureStore = InMemoryCaptureStore(seed: [open, closed])

        try await store.assignBatches([open.id: open.id, closed.id: open.id])

        #expect(try await store.all().map(\.batchID) == [open.id, closed.batchID])
    }

    @Test func deleteUnknownIDDoesNothing() async throws {
        let seed = [Capture(kind: .text)]
        let store: any CaptureStore = InMemoryCaptureStore(seed: seed)

        try await store.delete(id: UUID())

        #expect(try await store.all() == seed)
    }
}
