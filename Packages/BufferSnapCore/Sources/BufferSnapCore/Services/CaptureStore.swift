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
}
