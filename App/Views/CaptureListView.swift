import BufferSnapCore
import SwiftUI

/// The list of captures, grouped by batch, under whether everything reached Buffer and Sync now. With swipe-to-delete,
/// "Send now" on the open batch, Resend on failed ones, Clear Submitted, what went wrong last, and an empty state.
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
    /// How many ideas Clear Submitted would remove. The button shows only above zero.
    let clearableIdeaCount: Int
    /// Called once the user has confirmed clearing everything submitted.
    let onClearSubmitted: () -> Void
    /// Called when the user asks for the batching setting.
    let onShowBatchingSettings: () -> Void
    /// What the sign-in row shows while nobody is signed in, or `nil` while someone is.
    let signInPrompt: AppModel.SignInPrompt?
    /// Called when the user asks to sign in.
    let onSignIn: () -> Void
    /// Called when the user signs out.
    let onSignOut: () -> Void

    private var isSignedIn: Bool {
        signInPrompt == nil
    }

    var body: some View {
        List {
            Section {
                ScreenTitle("Captures")
            }
            if let signInPrompt {
                Section {
                    SignInPromptRow(prompt: signInPrompt, onSignIn: onSignIn)
                        .cardRow(verticalPadding: 14)
                }
            }
            if showsSyncStatus || problem != nil {
                Section {
                    let rows = (showsSyncStatus ? 1 : 0) + (problem == nil ? 0 : 1)
                    if showsSyncStatus {
                        SyncStatusRow(status: syncStatus, isSyncing: isSyncing, onSyncNow: onSyncNow)
                            .cardRow(CardPart(index: 0, count: rows))
                    }
                    if let problem {
                        CaptureListProblemRow(problem: problem)
                            .cardRow(CardPart(index: rows - 1, count: rows))
                    }
                }
            }
            // Signed out, the row above would run into it if it floated over the middle of the screen.
            if batches.isEmpty && problem == nil && !isSignedIn {
                Section {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            ForEach(batches) { batch in
                Section {
                    let captures = batch.newestFirst
                    ForEach(Array(captures.enumerated()), id: \.element.id) { index, capture in
                        CaptureRow(capture: capture, now: now)
                            .cardRow(CardPart(index: index, count: captures.count))
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
                    .paperInkSectionHeader()
                }
            }
        }
        .overlay {
            if batches.isEmpty && problem == nil && isSignedIn {
                emptyState
                    .padding(.horizontal, 22)
            }
        }
        .paperInkScreen(title: "Captures")
        .toolbar {
            if clearableIdeaCount > 0 {
                ChipToolbarItem(placement: .topBarLeading) {
                    ClearSubmittedButton(ideaCount: clearableIdeaCount, onClear: onClearSubmitted)
                }
            }
            ChipToolbarItem(placement: .topBarTrailing) {
                // In a menu, so one stray tap can't sign anyone out: coming back takes a full sign-in.
                Menu {
                    Button("Batching", systemImage: "square.stack", action: onShowBatchingSettings)
                    if isSignedIn {
                        Button(
                            "Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive,
                            action: onSignOut)
                    }
                } label: {
                    Label("Account", systemImage: "person")
                        .labelStyle(.iconOnly)
                }
                // A menu styled as a button keeps the chip in the toolbar, where a custom label lost it.
                .menuStyle(.button)
                .buttonStyle(.paperInkIconChip)
            }
        }
    }

    private var showsSyncStatus: Bool {
        syncStatus != .nothingYet && isSignedIn
    }

    /// How to start, the same signed in or not: the offline row already says where ideas go. The name is the control's
    /// and the widget's own, as the system lists it (`Widget/`). Each step is one literal, so it's a localized key and
    /// the Markdown renders.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No captures yet")
                .caveat(.title)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            EmptyStateStep(
                number: 1, text: Text("Add **Dictate an Idea** to Control Center, the Action button or a widget."))
            EmptyStateStep(number: 2, text: Text("Then press it and speak."))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One numbered step of the empty state.
private struct EmptyStateStep: View {
    let number: Int
    let text: Text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Badge(diameter: 26) {
                Text(number, format: .number)
                    .font(.inter(.footnote, weight: .heavy))
            }
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.center] + 5
            }
            text
                .font(.inter(.body))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
