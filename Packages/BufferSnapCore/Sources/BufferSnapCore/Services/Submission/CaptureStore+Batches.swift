extension CaptureStore {
    /// Every capture that hasn't gone yet.
    func pendingCaptures() async throws -> [Capture] {
        try await all().filter { $0.status == .pending }
    }

    /// Closes what's in `submission`, if `pending` says it isn't closed yet.
    func close(_ submission: Submission, among pending: [Capture]) async throws {
        var batchIDs: [Capture.ID: Capture.BatchID] = [:]
        for capture in pending where capture.batchID == nil && submission.captureIDs.contains(capture.id) {
            batchIDs[capture.id] = submission.batchID
        }
        if !batchIDs.isEmpty {
            try await assignBatches(batchIDs)
        }
    }
}
