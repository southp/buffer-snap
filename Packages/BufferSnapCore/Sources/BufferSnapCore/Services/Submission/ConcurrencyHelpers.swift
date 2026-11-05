import Foundation
import Synchronization

/// Hands each subscriber its own stream of the same events, as one `AsyncStream` can't have several consumers.
final class EventSubscribers<Event: Sendable>: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<Event>.Continuation]>([:])

    func subscribe() -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        continuations.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            _ = self?.continuations.withLock { $0.removeValue(forKey: id) }
        }
        return stream
    }

    func publish(_ event: Event) {
        continuations.withLock { continuations in
            for continuation in continuations.values {
                continuation.yield(event)
            }
        }
    }
}

extension Task where Success == Void, Failure == Never {
    /// Waits for this task, but stops waiting if the caller is cancelled, unlike `value`. This task carries on.
    func waitUnlessCancelled() async {
        let finished = AsyncStream<Void> { continuation in
            let waiter = Task<Void, Never> {
                await value
                continuation.finish()
            }
            continuation.onTermination = { _ in
                waiter.cancel()
            }
        }
        // Iterating a stream ends as soon as the task doing it is cancelled.
        for await _ in finished {}
    }
}
