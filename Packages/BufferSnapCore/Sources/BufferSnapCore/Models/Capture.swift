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

    public let id: UUID
    public var kind: Kind
    public var createdAt: Date
    public var status: Status
    /// The note's body for `.text`, or an optional caption for `.photo`.
    public var text: String?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = .now,
        status: Status = .pending,
        text: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.status = status
        self.text = text
    }
}
