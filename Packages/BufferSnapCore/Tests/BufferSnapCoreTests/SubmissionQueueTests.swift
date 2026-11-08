import BufferSnapCore
import Foundation
import Testing

struct SubmissionQueueTests {
    private let fixture = QueueFixture()
    private var server: FakeIdeasServer {
        fixture.server
    }

    @Test func aPendingCaptureBecomesAnIdeaAndShowsAsSubmitted() async throws {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)

        await queue.run()

        #expect(await server.ideas == [.init(text: "An idea", organizationID: "org-1")])
        #expect(await store.all().map(\.status) == [.submitted])
    }

    @Test func eachCaptureBecomesItsOwnIdeaOldestFirst() async {
        let store = InMemoryCaptureStore(seed: [.text("Second", at: 2), .text("Third", at: 3), .text("First", at: 1)])
        let queue = fixture.makeQueue(store: store)

        await queue.run()

        #expect(await server.ideaTexts == ["First", "Second", "Third"])
    }

    /// Nothing to send must cost no requests, so opening the app doesn't eat into the rate limit.
    @Test func nothingPendingMakesNoRequests() async throws {
        let captures = [Capture.text("Sent"), Capture.text("Failed")]
        let store = InMemoryCaptureStore(seed: captures)
        try await store.setStatus(.submitted, ids: [captures[0].id])
        try await store.setStatus(.failed, ids: [captures[1].id])
        let queue = fixture.makeQueue(store: store)

        await queue.run()

        #expect(await server.organizationRequests == 0)
        #expect(await server.ideaRequests == 0)
    }

    @Test func oneOrganizationLookupServesAPass() async {
        let store = InMemoryCaptureStore(seed: [.text("One", at: 1), .text("Two", at: 2)])
        let queue = fixture.makeQueue(store: store)

        await queue.run()

        #expect(await server.organizationRequests == 1)
        #expect(await server.ideas.map(\.organizationID) == ["org-1", "org-1"])
    }

    /// A pass that follows a sign-in as someone else mustn't use the organization of the last one.
    @Test func eachPassLooksUpTheOrganizationAgain() async throws {
        let store = InMemoryCaptureStore(seed: [.text("One")])
        let queue = fixture.makeQueue(store: store)
        await queue.run()
        await server.setOrganizations(["org-of-someone-else"])

        try await store.add(.text("Two"))
        await queue.run()

        #expect(await server.ideas.last?.organizationID == "org-of-someone-else")
    }

    /// Text only, for now. The rest stays pending, and doesn't stop what's behind it.
    @Test func whatCantBecomeAnIdeaIsSkipped() async {
        let photo = Capture(kind: .photo, createdAt: Date(timeIntervalSinceReferenceDate: 1), text: "A caption")
        let blank = Capture.text("  \n", at: 2)
        let store = InMemoryCaptureStore(seed: [photo, blank, .text("An idea", at: 3)])
        let queue = fixture.makeQueue(store: store)

        await queue.run()

        #expect(await server.ideaTexts == ["An idea"])
        #expect(await store.all().map(\.status) == [.pending, .pending, .submitted])
    }

    /// Until #41 lands, the widget's buttons still write these.
    @Test(arguments: [Capture.Kind.text, .photo])
    func mockCapturesNeverLeave(kind: Capture.Kind) async {
        let store = InMemoryCaptureStore(seed: [Capture(kind: kind, text: "Mock \(kind.rawValue) capture")])
        let queue = fixture.makeQueue(store: store)

        await queue.run()

        #expect(await server.ideaRequests == 0)
    }

    /// Launch and foreground can fire together, and two sends would be two ideas.
    @Test func overlappingRunsSendOnce() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.holdNextIdea()

        async let first: Void = queue.run()
        await server.waitForHeldIdea()
        async let second: Void = queue.run()
        async let third: Void = queue.run()
        // Time for a second pass to reach the server, if there were one.
        for _ in 0..<1_000 {
            await Task.yield()
        }
        #expect(await server.ideaRequests == 1)
        await server.releaseIdea()
        _ = await (first, second, third)

        #expect(await server.ideaRequests == 1)
    }

    @Test func aCaptureSavedDuringAPassIsSentByIt() async throws {
        let store = InMemoryCaptureStore(seed: [.text("First", at: 1)])
        let queue = fixture.makeQueue(store: store)
        await server.holdNextIdea()

        async let run: Void = queue.run()
        await server.waitForHeldIdea()
        try await store.add(.text("Second", at: 2))
        await server.releaseIdea()
        await run

        #expect(await server.ideaTexts == ["First", "Second"])
    }

    /// The tightest case: the pass has read the store and found nothing, and it's about to end.
    @Test func aCaptureSavedJustAsAPassEndsIsStillSent() async throws {
        let late = Capture.text("Late", at: 2)
        let store = StoreWithHookOnEmptyRead(seed: [.text("First", at: 1)])
        let queue = fixture.makeQueue(store: store)
        await store.setHook {
            await store.base.add(late)
            try? await queue.resend(late.id)
        }

        await queue.run()

        #expect(await server.ideaTexts == ["First", "Late"])
    }

    @Test func aCaptureDeletedBeforeItsTurnIsNotSent() async {
        let doomed = Capture.text("Deleted", at: 2)
        let store = InMemoryCaptureStore(seed: [.text("First", at: 1), doomed])
        let queue = fixture.makeQueue(store: store)
        await server.setOnIdea {
            await store.delete(id: doomed.id)
        }

        await queue.run()

        #expect(await server.ideaTexts == ["First"])
    }

    /// The idea exists either way, but the list has no capture to show it.
    @Test func aCaptureDeletedDuringItsSendStaysDeleted() async {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let queue = fixture.makeQueue(store: store)
        await server.setOnIdea {
            await store.delete(id: capture.id)
        }

        await queue.run()

        #expect(await store.all().isEmpty)
    }

    /// What a background task out of time relies on: it can stop waiting at once, and the send still finishes.
    @Test func cancellingACallerStopsTheWaitingButNotTheSend() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.holdNextIdea()

        let caller = Task {
            await queue.run()
        }
        await server.waitForHeldIdea()
        caller.cancel()
        await caller.value

        #expect(await store.all().map(\.status) == [.pending])
        await server.releaseIdea()
        await queue.run()
        #expect(await store.all().map(\.status) == [.submitted])
        #expect(await server.ideaRequests == 1)
    }

    /// What's pending survives quitting the app, because it's only in the store.
    @Test func aRelaunchSendsWhatsStillPending() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        await server.failIdeas(.offline)
        await fixture.makeQueue(store: store).run()
        #expect(await store.all().map(\.status) == [.pending])

        await fixture.makeQueue(store: store).run()

        #expect(await store.all().map(\.status) == [.submitted])
    }

    @Test func statusChangesAreAnnounced() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        let events = queue.events()

        await queue.run()

        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == .capturesChanged)
    }

    @Test func resendSendsAFailedCaptureAgain() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))
        await queue.run()
        #expect(await store.all().map(\.status) == [.failed])

        try await queue.resend(capture.id)
        await queue.run()

        #expect(await store.all().map(\.status) == [.submitted])
        #expect(await server.ideaTexts == ["An idea"])
    }

    /// A failed capture stays put until someone asks.
    @Test func aFailedCaptureIsNotSentByItself() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))

        await queue.run()
        await queue.run()

        #expect(await server.ideaRequests == 1)
    }
}
