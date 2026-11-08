import BufferSnapCore
import SwiftUI

/// The list of captures, grouped by batch, under whether everything reached Buffer and Sync now. With swipe-to-delete,
/// "Send now" on the open batch, Resend on failed ones, what went wrong last, and an empty state.
///
/// Stateless: it renders the batches it's given and forwards what's tapped, so snapshot tests can show any state
/// without loading anything. `CaptureListScreen` feeds it from `CaptureListModel`.
struct CaptureListView: View {
    /// The batches to show, in display order (newest first).
    let batches: [CaptureBatch]
    /// The moment relative timestamps count from.
    let now: Date
    /// Whether everything reached Buffer.
    let syncStatus: SyncStatus
    /// Whether a Sync now is running.
    let isSyncing: Bool
    /// What the list couldn't do last, if anything.
    let problem: CaptureListModel.Problem?
    /// Called when the user asks to send everything that can go.
    let onSyncNow: () -> Void
    /// Called when the user deletes a capture.
    let onDelete: (Capture) -> Void
    /// Called when the user asks to send the open batch without waiting.
    let onSendNow: () -> Void
    /// Called when the user asks to send a failed batch again.
    let onResend: (CaptureBatch) -> Void
    /// Called when the user asks for the batching setting.
    let onShowBatchingSettings: () -> Void
    /// Called when the user signs out.
    let onSignOut: () -> Void

    var body: some View {
        List {
            if syncStatus != .nothingYet || problem != nil {
                Section {
                    if syncStatus != .nothingYet {
                        SyncStatusRow(status: syncStatus, isSyncing: isSyncing, onSyncNow: onSyncNow)
                    }
                    if let problem {
                        CaptureListProblemRow(problem: problem)
                    }
                }
            }
            ForEach(batches) { batch in
                Section {
                    ForEach(batch.newestFirst) { capture in
                        CaptureRow(capture: capture, now: now)
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    onDelete(capture)
                                }
                            }
                    }
                } header: {
                    CaptureBatchHeader(batch: batch, now: now, onSendNow: onSendNow) {
                        onResend(batch)
                    }
                }
            }
        }
        .overlay {
            if batches.isEmpty && problem == nil {
                ContentUnavailableView(
                    "No captures yet",
                    systemImage: "tray",
                    description: Text("The ideas you capture show up here.")
                )
            }
        }
        .navigationTitle("Captures")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // In a menu, so one stray tap can't sign anyone out: coming back takes a full sign-in.
                Menu("Account", systemImage: "person.crop.circle") {
                    Button("Batching", systemImage: "square.stack", action: onShowBatchingSettings)
                    Button(
                        "Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive,
                        action: onSignOut)
                }
            }
        }
    }
}
