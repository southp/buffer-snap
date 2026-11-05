import BufferSnapCore
import SwiftUI

/// The list of captures, with swipe-to-delete, Resend on failed ones, and an empty state.
///
/// Stateless: it renders the captures it's given and forwards deletes, so snapshot tests can show any state without
/// loading anything. `CaptureListScreen` feeds it from `CaptureListModel`.
struct CaptureListView: View {
    /// The captures to show, in display order (newest first).
    let captures: [Capture]
    /// The moment relative timestamps count from.
    let now: Date
    /// Called when the user deletes a capture.
    let onDelete: (Capture) -> Void
    /// Called when the user asks to send a failed capture again.
    let onResend: (Capture) -> Void
    /// Called when the user signs out.
    let onSignOut: () -> Void

    var body: some View {
        List {
            ForEach(captures) { capture in
                CaptureRow(capture: capture, now: now) {
                    onResend(capture)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete(capture)
                    }
                }
            }
        }
        .overlay {
            if captures.isEmpty {
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
                    Button(
                        "Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive,
                        action: onSignOut)
                }
            }
        }
    }
}
