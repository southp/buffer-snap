import Observation

/// The list of captures, newest first, and the actions on it.
@Observable
@MainActor
public final class CaptureListModel {
    /// Stored captures, newest first. Empty until `load()` finishes.
    public private(set) var captures: [Capture] = []

    private let store: any CaptureStore
    private let submissions: SubmissionQueue

    public init(store: any CaptureStore, submissions: SubmissionQueue) {
        self.store = store
        self.submissions = submissions
    }

    /// Reads every capture from the store.
    public func load() async {
        do {
            captures = try await store.all().sorted { $0.createdAt > $1.createdAt }
        } catch {
            // Keep the last loaded list. Showing the error comes with the MVP.
        }
    }

    /// Loads, then again each time a send changes a capture's status, until the calling task is cancelled.
    public func loadAndFollowChanges() async {
        // Listen first, so a change while loading isn't missed.
        let events = submissions.events()
        await load()
        for await event in events where event == .capturesChanged {
            await load()
        }
    }

    /// Sends a failed capture again.
    public func resend(_ capture: Capture) async {
        do {
            try await submissions.resend(capture.id)
            await load()
        } catch {
            // It still shows as failed, so it can be tried again. Showing the error comes with the MVP.
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
