import Observation

/// The list of captures, newest first, and the actions on it.
@Observable
@MainActor
public final class CaptureListModel {
    /// Stored captures, newest first. Empty until `load()` finishes.
    public private(set) var captures: [Capture] = []

    private let store: any CaptureStore

    public init(store: any CaptureStore) {
        self.store = store
    }

    /// Reads every capture from the store.
    public func load() async {
        do {
            captures = try await store.all().sorted { $0.createdAt > $1.createdAt }
        } catch {
            // Keep the last loaded list. Showing the error comes with the MVP.
        }
    }

    /// Deletes `capture` from the store, then from the list.
    public func delete(_ capture: Capture) async {
        do {
            try await store.delete(id: capture.id)
            captures.removeAll { $0.id == capture.id }
        } catch {
            // Keep it listed, since the store still has it. Showing the error comes with the MVP.
        }
    }
}
