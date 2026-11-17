import BufferSnapCore
import Foundation
import Synchronization

/// An `AccountSource` that answers as a test says, counts what it's asked, and can hold an answer back.
actor StubAccountSource: AccountSource {
    private(set) var fetchCount = 0
    private var answers: [Result<BufferAccount, BufferError>]
    private var isHolding = false
    private var held: CheckedContinuation<Void, Never>?

    /// Answers with each of `answers` in turn, and then with the last one again.
    init(_ answers: Result<BufferAccount, BufferError>...) {
        self.answers = answers.isEmpty ? [.success(.ada)] : answers
    }

    func holdNextFetch() {
        isHolding = true
    }

    func waitForHeldFetch() async {
        while held == nil {
            await Task.yield()
        }
    }

    func releaseFetch() {
        held?.resume()
        held = nil
    }

    func fetchAccount() async throws -> BufferAccount {
        fetchCount += 1
        if isHolding {
            isHolding = false
            await withCheckedContinuation { held = $0 }
        }
        let answer = answers.count > 1 ? answers.removeFirst() : answers[0]
        return try answer.get()
    }
}

/// A clock a test moves by hand, for `AppModel`'s `now`.
final class ManualNow: Sendable {
    private let time = Mutex(Date(timeIntervalSinceReferenceDate: 1_000_000))

    var now: Date {
        time.withLock { $0 }
    }

    func advance(minutes: Double) {
        time.withLock { $0 = $0.addingTimeInterval(minutes * 60) }
    }
}

extension BufferAccount {
    static let ada = BufferAccount(name: "Ada Lovelace", email: "ada@example.com")
    static let grace = BufferAccount(name: "Grace Hopper", email: "grace@example.com")
}
