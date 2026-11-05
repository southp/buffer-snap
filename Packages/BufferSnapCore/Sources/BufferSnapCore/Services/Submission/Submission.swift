/// One idea to create, and the captures it came from. The captures' statuses change together with its fate.
public struct Submission: Sendable, Equatable {
    public let captureIDs: [Capture.ID]
    public let text: String

    public init(captureIDs: [Capture.ID], text: String) {
        self.captureIDs = captureIDs
        self.text = text
    }
}

/// Decides **what** to send next. `SubmissionQueue` decides how, and its callers decide when to try.
public protocol SubmissionPlanner: Sendable {
    /// The next idea to create from `pending`, which is oldest first, or `nil` if nothing should go now.
    func nextSubmission(from pending: [Capture]) -> Submission?
}

/// Each capture becomes its own idea, oldest first, until #45 groups them.
public struct OneIdeaPerCapture: SubmissionPlanner {
    public init() {}

    public func nextSubmission(from pending: [Capture]) -> Submission? {
        for capture in pending where capture.canBecomeAnIdea {
            if let text = capture.text {
                return Submission(captureIDs: [capture.id], text: text)
            }
        }
        return nil
    }
}

extension Capture {
    /// Only text can go for now: pictures have nowhere to go until there's a hosting decision
    /// (`docs/decisions/10-capture-kinds.md`). The widget's mock buttons wrote pending captures too, which must never
    /// reach someone's Buffer, whichever of this and #41's clean-up runs first.
    fileprivate var canBecomeAnIdea: Bool {
        guard kind == .text, let text, !text.allSatisfy(\.isWhitespace) else {
            return false
        }
        return text != "Mock \(kind.rawValue) capture"
    }
}
