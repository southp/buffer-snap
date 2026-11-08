import Foundation

/// One thing the user captured (a note or a photo), waiting to be sent to Buffer.
public struct Capture: Identifiable, Codable, Sendable, Equatable {
    /// What was captured.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case text
        case photo
    }

    /// Where the capture is on its way to Buffer.
    public enum Status: String, Codable, Sendable, CaseIterable {
        case pending
        case submitted
        case failed
    }

    /// Why a capture shows as failed, so the list can say what would help.
    public enum Failure: String, Codable, Sendable, CaseIterable {
        /// Buffer refused the idea, and asking again the same way won't change that.
        case refused
        /// Buffer kept failing with errors that may pass, `SubmissionQueue.maxServerFailures` times.
        case serverTrouble
        /// Held back when a sign-in started, as it may belong to someone else:
        /// `docs/decisions/44-hold-captures-at-sign-in.md`.
        case heldAtSignIn
    }

    /// Which batch of captures became, or will become, one idea.
    public typealias BatchID = UUID

    public let id: UUID
    public var kind: Kind
    public var createdAt: Date
    public var status: Status
    /// The note's body for `.text`, or an optional caption for `.photo`.
    public var text: String?
    /// The batch this capture was closed into. `nil` means it isn't closed yet, as it's still open to others joining,
    /// or it was made before batches existed: `docs/decisions/45-batch-membership.md`.
    public var batchID: BatchID?
    /// Why it failed, while `status` is `.failed`. `nil` for any other status, and for a capture that failed before
    /// the reason was kept.
    public var failure: Failure?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = .now,
        status: Status = .pending,
        text: String? = nil,
        batchID: BatchID? = nil,
        failure: Failure? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.status = status
        self.text = text
        self.batchID = batchID
        self.failure = failure
    }
}
