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

    /// Closes every batch in `batches` that's still open, all in one write.
    func closeOpenBatches(_ batches: [CaptureBatch]) async throws {
        var batchIDs: [Capture.ID: Capture.BatchID] = [:]
        for batch in batches {
            if case .open = batch.state {
                for capture in batch.captures {
                    batchIDs[capture.id] = batch.id
                }
            }
        }
        if !batchIDs.isEmpty {
            try await assignBatches(batchIDs)
        }
    }

    /// Makes a batch pending again and returns its captures. What's already sent stays that way.
    func reopen(_ batchID: Capture.BatchID) async throws -> [Capture.ID] {
        let unsent = try await all().filter {
            $0.status != .submitted && ($0.batchID == batchID || ($0.batchID == nil && $0.id == batchID))
        }
        guard !unsent.isEmpty else {
            return []
        }
        // Without a batch, it's from before there were any, and it could otherwise join whatever is open.
        var batchIDs: [Capture.ID: Capture.BatchID] = [:]
        for capture in unsent where capture.batchID == nil {
            batchIDs[capture.id] = batchID
        }
        if !batchIDs.isEmpty {
            try await assignBatches(batchIDs)
        }
        let ids = unsent.map(\.id)
        try await setStatus(.pending, ids: Set(ids))
        return ids
    }
}
