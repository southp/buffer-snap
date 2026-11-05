import BufferSnapCore
import Foundation
import Testing

struct ConnectivityTests {
    /// Launching already runs the queue, so how things stand at launch isn't news.
    @Test(arguments: [true, false])
    func theFirstUpdateIsNotAReconnection(isOnline: Bool) {
        var detector = ReconnectionDetector()

        let isReconnection = detector.update(isOnline: isOnline)

        #expect(!isReconnection)
    }

    @Test func onlyGoingFromOfflineToOnlineIsAReconnection() {
        var detector = ReconnectionDetector()

        // Offline at launch, back, a move from Wi-Fi to cellular, offline again, and back again.
        let updates = [false, true, true, false, true].map { detector.update(isOnline: $0) }

        #expect(updates == [false, true, false, false, true])
    }

    /// The issue's airplane mode case, with nothing else nudging the queue and the back-off still running.
    @Test func aCaptureMadeOfflineIsSentWhenTheConnectionReturns() async {
        let fixture = QueueFixture()
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        let monitor = MockConnectivityMonitor()
        await fixture.server.failIdeas(.offline)
        await queue.run()
        #expect(await store.all().map(\.status) == [.pending])

        let watcher = Task {
            await queue.runOnEachReconnection(of: monitor)
        }
        // Keeps reporting, as the watcher only hears what comes after it has subscribed.
        while await store.all().map(\.status) != [.submitted] {
            monitor.reconnect()
            await Task.yield()
        }
        watcher.cancel()

        #expect(await fixture.server.ideaTexts == ["An idea"])
    }
}
