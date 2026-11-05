import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The capture screen, rendered full-screen to AppTests/__Snapshots__/CaptureViewTests/.
///
/// Wrapped in a `NavigationStack`, as `RootView` shows it, so the title renders. Toolbar items don't render in these
/// snapshots, so the button that opens the list is missing from them.
@MainActor
struct CaptureViewTests {
    /// Nothing typed: the placeholder, a zero count, Save disabled, and room below for the mic.
    @Test func empty() {
        assertScreenSnapshot(of: captureScreen(text: "", canSave: false), named: "empty")
    }

    /// An idea being typed: its count, and Save enabled.
    @Test func typing() {
        assertScreenSnapshot(of: captureScreen(text: "Idea for Friday's post", canSave: true), named: "typing")
    }

    /// Exactly 300 characters: every line fits, and Save stays enabled.
    @Test func atLimit() {
        let text = String(repeating: "Ideas add up. ", count: 21) + "Ideas."
        #expect(text.count == CaptureModel.characterLimit)
        assertScreenSnapshot(of: captureScreen(text: text, canSave: true), named: "atLimit")
    }

    /// Over the limit: the count turns red and Save is disabled.
    @Test func overLimit() {
        let text = String(repeating: "Ideas add up. ", count: 21) + "Ideas add up!"
        assertScreenSnapshot(
            of: captureScreen(text: text, isOverLimit: true, canSave: false),
            named: "overLimit"
        )
    }

    /// Just saved: an empty box again, and the confirmation.
    @Test func saved() {
        assertScreenSnapshot(of: captureScreen(text: "", canSave: false, saveResult: .saved), named: "saved")
    }

    /// The save failed: the draft is still there, with the error, and Save can retry.
    @Test func failed() {
        assertScreenSnapshot(
            of: captureScreen(text: "Idea for Friday's post", canSave: true, saveResult: .failed),
            named: "failed"
        )
    }

    private func captureScreen(
        text: String,
        isOverLimit: Bool = false,
        canSave: Bool,
        saveResult: CaptureModel.SaveResult? = nil
    ) -> some View {
        NavigationStack {
            CaptureView(
                text: .constant(text),
                characterCount: text.count,
                characterLimit: CaptureModel.characterLimit,
                isOverLimit: isOverLimit,
                canSave: canSave,
                saveResult: saveResult,
                onSave: {},
                onShowCaptures: {}
            )
        }
    }
}
