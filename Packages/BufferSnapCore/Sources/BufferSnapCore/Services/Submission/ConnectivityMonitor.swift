import Foundation
import Network
import Synchronization

/// Tells when the iPhone gets a connection back.
public protocol ConnectivityMonitor: Sendable {
    /// Yields each time being offline ends, from now until the stream's consumer goes away.
    func reconnections() -> AsyncStream<Void>
}

/// Spots being offline ending in a series of path updates. The first update isn't a reconnection: it's only how things
/// stand at launch, and launching runs the queue anyway.
public struct ReconnectionDetector: Sendable {
    private var wasOnline: Bool?

    public init() {}

    public mutating func update(isOnline: Bool) -> Bool {
        defer {
            wasOnline = isOnline
        }
        return wasOnline == false && isOnline
    }
}

/// The real monitor, on `NWPathMonitor`. It only hears anything while the app is running, so a connection that returns
/// while the app is suspended is picked up by returning to the foreground instead.
public struct NetworkPathConnectivityMonitor: ConnectivityMonitor {
    public init() {}

    public func reconnections() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let detector = Mutex(ReconnectionDetector())
            monitor.pathUpdateHandler = { path in
                if detector.withLock({ $0.update(isOnline: path.status == .satisfied) }) {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue(label: "me.southp.buffersnap.connectivity"))
        }
    }
}

/// A `ConnectivityMonitor` that only reconnects when told to, for tests and the mocked app.
public final class MockConnectivityMonitor: ConnectivityMonitor {
    private let subscribers = EventSubscribers<Void>()

    public init() {}

    public func reconnections() -> AsyncStream<Void> {
        subscribers.subscribe()
    }

    public func reconnect() {
        subscribers.publish(())
    }
}

extension SubmissionQueue {
    /// Runs the queue each time `monitor` reports a connection coming back, until the calling task is cancelled.
    public func runOnEachReconnection(of monitor: any ConnectivityMonitor) async {
        for await _ in monitor.reconnections() {
            await run()
        }
    }
}
