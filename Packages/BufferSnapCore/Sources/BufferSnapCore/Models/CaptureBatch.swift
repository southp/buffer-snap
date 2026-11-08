import Foundation

/// Captures that become one idea, in the order they were made.
///
/// An open batch is worked out from timestamps, and a closed one from its captures' `batchID`:
/// `docs/decisions/45-batch-membership.md`.
public struct CaptureBatch: Identifiable, Sendable, Equatable {
    /// Where the batch is on its way to Buffer.
    public enum State: Sendable, Equatable {
        /// Goes at `sendsAt`, unless another capture comes first, which pushes that back.
        case open(sendsAt: Date)
        /// Closed, so it's the next to go whenever it can.
        case closed
        case submitted
        case failed
        /// Pending, but it can't become an idea for now, as with a picture.
        case unsendable
    }

    public let id: Capture.BatchID
    public let captures: [Capture]
    public let state: State

    /// The captures as the list shows them: newest first, like the batches themselves, so a new capture is always at
    /// the top. `captures` stays oldest first, the order they go to Buffer in.
    public var newestFirst: [Capture] {
        captures.reversed()
    }

    /// The idea's text, or `nil` if it has none to send. The blank lines keep the captures apart once they're in
    /// Buffer.
    public var text: String? {
        let texts = captures.compactMap(\.ideaText)
        return texts.isEmpty ? nil : texts.joined(separator: "\n\n")
    }

    /// Why it failed, if it did and that was kept. A batch fails as a whole, so its captures share the reason.
    public var failure: Capture.Failure? {
        guard state == .failed else {
            return nil
        }
        return captures.lazy.compactMap(\.failure).first
    }

    /// Whether it's still counting down at `now`, so that "Send now" would make a difference.
    public func isWaiting(at now: Date) -> Bool {
        guard case .open(let sendsAt) = state else {
            return false
        }
        return sendsAt > now
    }

    /// Groups `captures` into batches, oldest first.
    ///
    /// A pending capture with no batch joins the one before it if there's less than `window` between them, so the
    /// window restarts after each capture. A `window` of 0 or less means each capture goes by itself.
    public static func batches(of captures: [Capture], window: TimeInterval) -> [CaptureBatch] {
        var closed: [Capture.BatchID: [Capture]] = [:]
        var open: [[Capture]] = []
        var others: [Capture] = []
        for capture in captures.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let batchID = capture.batchID {
                closed[batchID, default: []].append(capture)
            } else if capture.status != .pending || capture.ideaText == nil {
                others.append(capture)
            } else if let last = open.last?.last, capture.createdAt.timeIntervalSince(last.createdAt) < window {
                open[open.count - 1].append(capture)
            } else {
                open.append([capture])
            }
        }
        let batches =
            closed.map { CaptureBatch(id: $0.key, captures: $0.value, state: closedState(of: $0.value)) }
            + open.map { CaptureBatch(open: $0, window: window) }
            + others.map { CaptureBatch(id: $0.id, captures: [$0], state: closedState(of: [$0])) }
        return batches.sorted { $0.startedAt < $1.startedAt }
    }

    private var startedAt: Date {
        captures.first?.createdAt ?? .distantPast
    }

    private init(id: Capture.BatchID, captures: [Capture], state: State) {
        self.id = id
        self.captures = captures
        self.state = state
    }

    /// `captures` is never empty, as a batch only starts with a capture.
    private init(open captures: [Capture], window: TimeInterval) {
        let last = captures.last?.createdAt ?? .distantPast
        self.init(
            id: captures.first?.id ?? UUID(),
            captures: captures,
            state: .open(sendsAt: last.addingTimeInterval(max(window, 0)))
        )
    }

    /// A batch's captures change status together. If that ever breaks, what's pending still goes, and only then does
    /// what failed ask for a tap, so nothing gets stuck.
    private static func closedState(of captures: [Capture]) -> State {
        if captures.contains(where: { $0.status == .pending }) {
            return captures.contains { $0.ideaText != nil } ? .closed : .unsendable
        }
        return captures.contains { $0.status == .failed } ? .failed : .submitted
    }
}

extension Capture {
    /// The text this capture adds to an idea, or `nil` if it can't become one.
    ///
    /// Only text can go for now: pictures have nowhere to go until there's a hosting decision
    /// (`docs/decisions/10-capture-kinds.md`). The widget's mock buttons wrote pending captures too, which must never
    /// reach someone's Buffer, whichever of this and #41's clean-up runs first.
    fileprivate var ideaText: String? {
        guard kind == .text, let text, !text.allSatisfy(\.isWhitespace), text != "Mock \(kind.rawValue) capture" else {
            return nil
        }
        return text
    }
}
