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

    public init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = .now,
        status: Status = .pending,
        text: String? = nil,
        batchID: BatchID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.status = status
        self.text = text
        self.batchID = batchID
    }
}
