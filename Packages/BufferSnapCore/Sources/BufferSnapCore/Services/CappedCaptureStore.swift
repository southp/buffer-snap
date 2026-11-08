import OSLog

/// A `CaptureStore` that keeps at most `limit` captures by deleting the oldest submitted ones, and never an unsent one:
/// `docs/decisions/46-storage-limit.md`.
///
/// It trims each time captures become submitted, the only moment one can become droppable. While more than `limit`
/// haven't gone, it keeps them all.
public struct CappedCaptureStore: CaptureStore {
    /// How many captures the app keeps.
    public static let defaultLimit = 500

    private let base: any CaptureStore
    private let limit: Int

    public init(base: any CaptureStore, limit: Int = Self.defaultLimit) {
        self.base = base
        self.limit = limit
    }

    public func all() async throws -> [Capture] {
        try await base.all()
    }

    public func add(_ capture: Capture) async throws {
        try await base.add(capture)
    }

    public func delete(id: Capture.ID) async throws {
        try await base.delete(id: id)
    }

    public func setStatus(_ status: Capture.Status, failure: Capture.Failure?, ids: Set<Capture.ID>) async throws {
        try await base.setStatus(status, failure: failure, ids: ids)
        guard status == .submitted else {
            return
        }
        do {
            try await dropOldestSubmitted()
        } catch {
            // The status was saved, which is what the caller asked for. Keeping a few extra loses nothing, and the
            // next send trims again.
            Logger.submission.error(
                "Can't trim the stored captures: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    public func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws {
        try await base.assignBatches(batchIDs)
    }

    private func dropOldestSubmitted() async throws {
        let captures = try await base.all()
        let excess = captures.count - limit
        guard excess > 0 else {
            return
        }
        let oldestSent = captures.filter { $0.status == .submitted }.sorted { $0.createdAt < $1.createdAt }
        for capture in oldestSent.prefix(excess) {
            try await base.delete(id: capture.id)
        }
    }
}
