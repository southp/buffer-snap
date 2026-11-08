import BufferSnapCore
import Foundation
import Testing

/// The storage limit: `docs/decisions/46-storage-limit.md`. Timestamps are seconds after a fixed date.
struct CappedCaptureStoreTests {
    private func capture(_ text: String, at seconds: TimeInterval, _ status: Capture.Status) -> Capture {
        Capture(kind: .text, createdAt: Date(timeIntervalSinceReferenceDate: seconds), status: status, text: text)
    }

    @Test func theDefaultLimitIsFiveHundred() {
        #expect(CappedCaptureStore.defaultLimit == 500)
    }

    @Test func sendingPastTheLimitDropsTheOldestSentOnes() async throws {
        let base = InMemoryCaptureStore(seed: [
            capture("Oldest sent", at: 0, .submitted),
            capture("Sent", at: 1, .submitted),
            capture("Newest", at: 2, .pending),
        ])
        let store = CappedCaptureStore(base: base, limit: 2)
        let newest = try #require(await base.all().last)

        try await store.setStatus(.submitted, ids: [newest.id])

        #expect(await base.all().map(\.text) == ["Sent", "Newest"])
    }

    /// An unsent capture exists nowhere else, so the limit gives way instead.
    @Test func neverDropsAnUnsentCapture() async throws {
        let sent = capture("Sent", at: 3, .submitted)
        let base = InMemoryCaptureStore(seed: [
            capture("Failed", at: 0, .failed),
            capture("Pending", at: 1, .pending),
            capture("Also pending", at: 2, .pending),
            sent,
        ])
        let store = CappedCaptureStore(base: base, limit: 1)

        try await store.setStatus(.submitted, ids: [sent.id])

        #expect(await base.all().map(\.text) == ["Failed", "Pending", "Also pending"])
    }

    @Test func underTheLimitNothingIsDropped() async throws {
        let base = InMemoryCaptureStore(seed: [capture("Sent", at: 0, .submitted), capture("New", at: 1, .pending)])
        let store = CappedCaptureStore(base: base, limit: 2)
        let new = try #require(await base.all().last)

        try await store.setStatus(.submitted, ids: [new.id])

        #expect(await base.all().count == 2)
    }

    /// Only a send makes room: a new capture or a failure doesn't drop anything.
    @Test func onlyBecomingSubmittedTrims() async throws {
        let failing = capture("Failing", at: 2, .pending)
        let base = InMemoryCaptureStore(seed: [
            capture("Sent", at: 0, .submitted), capture("Sent too", at: 1, .submitted),
        ])
        let store = CappedCaptureStore(base: base, limit: 1)

        try await store.add(failing)
        try await store.setStatus(.failed, ids: [failing.id])

        #expect(await base.all().count == 3)
    }

    /// The queue saves what was sent through the store it's given, so the limit holds without it knowing.
    @Test func theQueueSendingPastTheLimitTrims() async throws {
        let base = InMemoryCaptureStore(seed: [capture("Old", at: 0, .submitted), capture("New", at: 1, .pending)])
        let store = CappedCaptureStore(base: base, limit: 1)
        let queue = SubmissionQueue(
            store: store,
            auth: MockAuthService(hasSavedSession: true),
            client: MockBufferClient()
        )

        await queue.run()

        #expect(await base.all().map(\.text) == ["New"])
    }
}
