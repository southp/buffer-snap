extension CaptureStore {
    /// Deletes the captures the widget's old mock buttons made, before #41 replaced them, and nothing else.
    ///
    /// They share a file with real captures, so a capture only counts as a mock if its whole text is what those buttons
    /// wrote for its kind (`docs/decisions/41-remove-mock-captures-by-text.md`).
    public func removeMockCaptures() async throws {
        for capture in try await all() where capture.text == "Mock \(capture.kind.rawValue) capture" {
            try await delete(id: capture.id)
        }
    }
}
