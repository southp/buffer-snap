/// A `CaptureStore` that calls `onChange` after every successful write to the store it wraps.
///
/// The app wraps its store in this to reload the widget's timelines, so no mutation can forget to and Core stays
/// free of WidgetKit.
public struct NotifyingCaptureStore: CaptureStore {
    private let base: any CaptureStore
    private let onChange: @Sendable () -> Void

    public init(base: any CaptureStore, onChange: @escaping @Sendable () -> Void) {
        self.base = base
        self.onChange = onChange
    }

    public func all() async throws -> [Capture] {
        try await base.all()
    }

    public func add(_ capture: Capture) async throws {
        try await base.add(capture)
        onChange()
    }

    public func delete(id: Capture.ID) async throws {
        try await base.delete(id: id)
        onChange()
    }

    public func deleteSubmitted() async throws {
        try await base.deleteSubmitted()
        onChange()
    }

    public func setStatus(_ status: Capture.Status, failure: Capture.Failure?, ids: Set<Capture.ID>) async throws {
        try await base.setStatus(status, failure: failure, ids: ids)
        onChange()
    }

    public func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws {
        try await base.assignBatches(batchIDs)
        onChange()
    }
}
