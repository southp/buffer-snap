import BufferSnapCore
import Foundation
import Testing

/// What the list's sync status reads from the queue: whether Buffer could be reached.
struct SubmissionQueueSyncTests {
    private let fixture = QueueFixture()
    private var server: FakeIdeasServer {
        fixture.server
    }

    @Test func aPassWithNoConnectionIsOfflineUntilOneGetsThrough() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.offline)

        await queue.run()
        #expect(await queue.isOffline)

        await queue.run()
        #expect(await queue.isOffline == false)
        #expect(await store.all().map(\.status) == [.submitted])
    }

    /// Buffer answered, so the connection is fine: the capture still goes by itself.
    @Test func aServerErrorIsntOffline() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.serverError))

        await queue.run()

        #expect(await queue.isOffline == false)
    }

    /// Offline while refreshing the token is still offline.
    @Test func noConnectionForATokenIsOffline() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store, auth: StubAuthService(tokenError: AuthError.network))

        await queue.run()

        #expect(await queue.isOffline)
    }

    /// The list follows the queue's events, so going offline has to be one.
    @Test func goingOfflineIsAnEvent() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.offline)
        let events = queue.events()

        await queue.run()

        for await event in events where event == .reachabilityChanged {
            break
        }
        #expect(await queue.isOffline)
    }
}
