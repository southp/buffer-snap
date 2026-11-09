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
    /// What the sign-in row shows while nobody is signed in, or `nil` while someone is.
    let signInPrompt: AppModel.SignInPrompt?
    /// Called when the user asks to sign in.
    let onSignIn: () -> Void
    /// Called when the user asks to type an idea.
    let onTypeIdea: () -> Void
    /// Called when the user signs out.
    let onSignOut: () -> Void

    private var isSignedIn: Bool {
        signInPrompt == nil
    }

    var body: some View {
        List {
            if let signInPrompt {
                Section {
                    SignInPromptRow(prompt: signInPrompt, onSignIn: onSignIn)
                }
            }
            if syncStatus != .nothingYet && isSignedIn || problem != nil {
                Section {
                    if syncStatus != .nothingYet && isSignedIn {
                        SyncStatusRow(status: syncStatus, isSyncing: isSyncing, onSyncNow: onSyncNow)
                    }
                    if let problem {
                        CaptureListProblemRow(problem: problem)
                    }
                }
            }
            // Signed out, the row above would run into it if it floated over the middle of the screen.
            if batches.isEmpty && problem == nil && !isSignedIn {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
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
                    CaptureBatchHeader(batch: batch, now: now, isSignedIn: isSignedIn, onSendNow: onSendNow) {
                        onResend(batch)
                    }
                }
            }
        }
        .overlay {
            if batches.isEmpty && problem == nil && isSignedIn {
                emptyState
            }
        }
        .navigationTitle("Captures")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // In a menu, so one stray tap can't sign anyone out: coming back takes a full sign-in.
                Menu("Account", systemImage: "person.crop.circle") {
                    Button("Type an Idea", systemImage: "square.and.pencil", action: onTypeIdea)
                    Button("Batching", systemImage: "square.stack", action: onShowBatchingSettings)
                    if isSignedIn {
                        Button(
                            "Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive,
                            action: onSignOut)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No captures yet",
            systemImage: "mic.fill",
            description: emptyDescription
        )
    }

    /// The names are the control's and the widget's own, as the system lists them (`Widget/`). One literal each, so
    /// it's a localized key and the Markdown renders.
    private var emptyDescription: Text {
        if isSignedIn {
            Text(
                """
                Add **Dictate an Idea** to Control Center or the Action button, or put the **Dictate an Idea** \
                widget on your Home Screen. Press it and speak: your idea shows up here and goes to Buffer.
                """
            )
        } else {
            Text(
                """
                Add **Dictate an Idea** to Control Center or the Action button, or put the **Dictate an Idea** \
                widget on your Home Screen. Press it and speak: your idea is saved here on this iPhone.
                """
            )
        }
    }
}
