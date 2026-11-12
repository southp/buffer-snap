import BufferSnapCore
import Foundation
import Observation
import Synchronization
import Testing

/// What the list shows while Buffer asks BufSnap to wait, on a clock the test moves: one capture whose first try gets a
/// 429 with `Retry-After: 753`.
@MainActor
struct RateLimitedListTests {
    private static let retryAfter: TimeInterval = 753

    private let fixture = QueueFixture()
    private let store = InMemoryCaptureStore(seed: [.text("An idea")])
    /// When the wait ends: the clock starts at the same time in every test, and no jitter is added.
    private let until: Date
    private var clock: ManualSubmissionClock {
        fixture.clock
    }
    private var server: FakeIdeasServer {
        fixture.server
    }

    init() {
        until = fixture.clock.now.addingTimeInterval(Self.retryAfter)
    }

    /// Rate limits the queue, and returns it with a loaded list.
    private func rateLimitedList() async -> (SubmissionQueue, CaptureListModel) {
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.tooManyRequests(retryAfter: Int(Self.retryAfter))))
        await queue.run()
        let model = CaptureListModel(store: store, submissions: queue)
        await model.load()
        return (queue, model)
    }

    @Test func aRateLimitSaysUntilWhen() async {
        let (queue, model) = await rateLimitedList()

        #expect(await queue.rateLimitedUntil == until)
        #expect(model.syncStatus(at: clock.now) == .rateLimited(count: 1, until: until))
        #expect(model.syncStatus(at: clock.now).canSyncNow == false)
    }

    /// "Syncing…" would flash for a pass that can't start, and nothing would say why.
    @Test func syncNowDuringARateLimitDoesNothing() async {
        let (_, model) = await rateLimitedList()
        let isSyncingChanged = Mutex(false)
        withObservationTracking {
            _ = model.isSyncing
        } onChange: {
            isSyncingChanged.withLock { $0 = true }
        }

        await model.syncNow()

        #expect(isSyncingChanged.withLock { $0 } == false)
        #expect(await server.ideaRequests == 1)
        #expect(model.syncStatus(at: clock.now) == .rateLimited(count: 1, until: until))
    }

    /// Once the time has passed, the status says waiting again, even before the queue wakes up.
    @Test func theWaitEndsOnTime() async {
        let (queue, model) = await rateLimitedList()

        #expect(model.syncStatus(at: until.addingTimeInterval(-1)) == .rateLimited(count: 1, until: until))
        #expect(model.syncStatus(at: until) == .waiting(count: 1, nextSendAt: nil))
        clock.advance(by: Self.retryAfter)
        #expect(await queue.rateLimitedUntil == nil)
    }

    @Test func syncNowWorksAgainAfterTheWait() async {
        let (_, model) = await rateLimitedList()
        clock.advance(by: Self.retryAfter)

        await model.syncNow()

        #expect(await server.ideaRequests == 2)
        #expect(model.syncStatus(at: clock.now) == .allSent)
    }

    /// The list follows the queue's events, so both the start and the end of a wait have to be one.
    @Test func theListFollowsTheWaitFromStartToEnd() async {
        let queue = fixture.makeQueue(store: store)
        let model = CaptureListModel(store: store, submissions: queue)
        let following = Task {
            await model.loadAndFollowChanges()
        }
        defer {
            following.cancel()
        }
        await waitUntil { model.captures.count == 1 }
        await server.failIdeas(.answer(.tooManyRequests(retryAfter: Int(Self.retryAfter))))

        await queue.run()
        await waitUntil { model.rateLimitedUntil != nil }
        #expect(model.rateLimitedUntil == until)
        #expect(model.syncStatus(at: clock.now) == .rateLimited(count: 1, until: until))

        _ = await clock.waitForSleep(number: 1)
        clock.finishLatestSleep()
        await waitUntil { model.syncStatus(at: clock.now) == .allSent }
        #expect(model.rateLimitedUntil == nil)
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        while await !condition() {
            await Task.yield()
        }
    }
}
