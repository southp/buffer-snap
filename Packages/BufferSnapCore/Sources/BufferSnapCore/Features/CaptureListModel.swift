import Observation

/// The list of captures, newest first, and the actions on it.
@Observable
@MainActor
public final class CaptureListModel {
    /// Stored captures, newest first. Empty until `load()` finishes.
    public private(set) var captures: [Capture] = [] {
        didSet {
            batches = submissions.batches(of: captures).reversed()
        }
    }
    /// The same captures in the batches they'll go or went in, newest first. Inside a batch, they're in the order they
    /// were made, which is how they read in the idea.
    public private(set) var batches: [CaptureBatch] = []

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

    /// Sends a failed batch again, as one idea.
    public func resend(_ batch: CaptureBatch) async {
        do {
            try await submissions.resend(batch.id)
            await load()
        } catch {
            // It still shows as failed, so it can be tried again. Showing the error comes with the MVP.
        }
    }

    /// Sends the open batch without waiting for its window to end.
    public func sendNow() async {
        do {
            try await submissions.sendNow()
            await load()
        } catch {
            // It still shows when it will go, and goes then. Showing the error comes with the MVP.
        }
    }

    /// Deletes `capture` from the store, then from the list. If it set when its batch goes, that time moves.
    public func delete(_ capture: Capture) async {
        do {
            try await store.delete(id: capture.id)
            captures.removeAll { $0.id == capture.id }
            await submissions.replan()
        } catch {
            // Keep it listed, since the store still has it. Showing the error comes with the MVP.
        }
    }
}
