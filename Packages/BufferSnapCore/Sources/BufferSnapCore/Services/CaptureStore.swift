/// Where captures are kept between launches, shared by the app and the widget.
///
/// The real implementation, `JSONFileCaptureStore`, is an `actor` doing file I/O, so the API is `async throws` and
/// `Sendable`.
public protocol CaptureStore: Sendable {
    /// Every stored capture, in no particular order.
    func all() async throws -> [Capture]
    /// Stores `capture`.
    func add(_ capture: Capture) async throws
    /// Removes the capture with `id`. Does nothing if there is none.
    func delete(id: Capture.ID) async throws
    /// Changes the status of the captures with `ids`, all in one write. Skips any that are gone, so an upload finishing
    /// can't bring back a capture deleted while it ran.
    func setStatus(_ status: Capture.Status, ids: Set<Capture.ID>) async throws
    /// Closes captures into the batches `batchIDs` names, all in one write. Skips any that are gone, and any already
    /// in a batch, as a batch must stay the same once it's closed.
    func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws
}

/// A `CaptureStore` that keeps captures in memory, for tests, previews and the mocked app.
public actor InMemoryCaptureStore: CaptureStore {
    private var captures: [Capture]

    /// Creates a store that starts with `seed`.
    public init(seed: [Capture] = []) {
        captures = seed
    }

    public func all() -> [Capture] {
        captures
    }

    public func add(_ capture: Capture) {
        captures.append(capture)
    }

    public func delete(id: Capture.ID) {
        captures.removeAll { $0.id == id }
    }

    public func setStatus(_ status: Capture.Status, ids: Set<Capture.ID>) {
        for index in captures.indices where ids.contains(captures[index].id) {
            captures[index].status = status
        }
    }

    public func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) {
        for index in captures.indices where captures[index].batchID == nil {
            captures[index].batchID = batchIDs[captures[index].id]
        }
    }
}
