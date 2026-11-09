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

    @Test func deleteSubmittedReachesTheStoreItWraps() async throws {
        let base = InMemoryCaptureStore(seed: [capture("Sent", at: 0, .submitted), capture("Failed", at: 1, .failed)])
        let store = CappedCaptureStore(base: base, limit: 2)

        try await store.deleteSubmitted()

        #expect(await base.all().map(\.text) == ["Failed"])
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

    // MARK: - Signed out, nothing ever drains the store

    /// Past the limit while signed out, every idea stays: the limit gives way, and nothing drops silently.
    @Test func signedOutPastTheLimitKeepsEveryIdea() async throws {
        let base = InMemoryCaptureStore()
        let store = CappedCaptureStore(base: base, limit: 2)
        let queue = SubmissionQueue(store: store, auth: MockAuthService(), client: MockBufferClient())

        for seconds in 0..<5 {
            try await store.add(capture("Idea \(seconds)", at: Double(seconds), .pending))
            await queue.run()
        }

        #expect(await base.all().count == 5)
        #expect(await base.all().allSatisfy { $0.status == .pending })
    }

    /// Past the limit at sign-in, every idea reaches Buffer before anything is trimmed, and only sent ones go.
    @Test func signingInPastTheLimitSendsEveryIdeaBeforeTrimming() async throws {
        let base = InMemoryCaptureStore(seed: [
            capture("Old sent", at: 0, .submitted),
            capture("First", at: 1, .pending),
            capture("Second", at: 2, .pending),
            capture("Third", at: 3, .pending),
        ])
        let store = CappedCaptureStore(base: base, limit: 2)
        let buffer = MockBufferClient()
        let auth = MockAuthService()
        let queue = SubmissionQueue(store: store, auth: auth, client: buffer)
        let model = await AppModel(auth: auth, ideas: queue)

        await model.signIn()
        #expect(await model.ideasToConfirm == 3)
        await model.sendHeldIdeas()
        await queue.run()

        #expect(await buffer.createdIdeas == ["First", "Second", "Third"])
        #expect(await base.all().allSatisfy { $0.status == .submitted })
        #expect(await base.all().count == 2)
    }
}
