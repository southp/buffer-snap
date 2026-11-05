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
    /// Nothing typed: the placeholder, a zero count, Save disabled, and the mic ready.
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

    /// Holding the mic: live text in the box, Save disabled, and the mic showing it's listening.
    @Test func listening() {
        assertScreenSnapshot(
            of: captureScreen(text: "Idea for Friday's post", canSave: false, dictation: .listening),
            named: "listening"
        )
    }

    /// Mixed Chinese and English live text, the way it's mostly spoken.
    @Test func listeningInMixedLanguages() {
        assertScreenSnapshot(
            of: captureScreen(text: "週五的 post 可以寫 Buffer 的新功能", canSave: false, dictation: .listening),
            named: "listeningInMixedLanguages"
        )
    }

    /// Released: waiting for the last words, with Save still disabled.
    @Test func finishing() {
        assertScreenSnapshot(
            of: captureScreen(text: "Idea for Friday's post", canSave: false, dictation: .finishing),
            named: "finishing"
        )
    }

    /// Saved by releasing: an empty box again, and the confirmation.
    @Test func dictationSaved() {
        assertScreenSnapshot(
            of: captureScreen(text: "", canSave: false, saveResult: .saved, dictation: .finished(.saved)),
            named: "dictationSaved"
        )
    }

    /// A quick tap or a silent hold: nothing saved, and a nudge on how to use the mic.
    @Test func nothingHeard() {
        assertScreenSnapshot(
            of: captureScreen(text: "", canSave: false, dictation: .finished(.nothingHeard)),
            named: "nothingHeard"
        )
    }

    /// A long ramble: the words wait in the box to be shortened, with the count in red.
    @Test func dictationTooLong() {
        let text = String(repeating: "Ideas add up. ", count: 21) + "Ideas add up!"
        assertScreenSnapshot(
            of: captureScreen(text: text, isOverLimit: true, canSave: false, dictation: .finished(.tooLong)),
            named: "dictationTooLong"
        )
    }

    /// Microphone refused: says why, offers Settings, and typing still works.
    @Test func microphoneDenied() {
        assertScreenSnapshot(
            of: captureScreen(text: "Typed anyway", canSave: true, dictation: .failed(.microphoneDenied)),
            named: "microphoneDenied"
        )
    }

    /// Speech recognition refused: says why, and offers Settings.
    @Test func speechRecognitionDenied() {
        assertScreenSnapshot(
            of: captureScreen(text: "", canSave: false, dictation: .failed(.speechRecognitionDenied)),
            named: "speechRecognitionDenied"
        )
    }

    /// Not allowed on this iPhone: says so, with no Settings to offer.
    @Test func restricted() {
        assertScreenSnapshot(
            of: captureScreen(text: "", canSave: false, dictation: .failed(.restricted)),
            named: "restricted"
        )
    }

    /// Recognition can't run now: says so, and leaves typing as the way forward.
    @Test func unavailable() {
        assertScreenSnapshot(
            of: captureScreen(text: "", canSave: false, dictation: .failed(.unavailable)),
            named: "unavailable"
        )
    }

    /// A call arrived while holding: the words stay in the box, unsaved.
    @Test func interrupted() {
        assertScreenSnapshot(
            of: captureScreen(text: "Before the call", canSave: true, dictation: .failed(.interrupted)),
            named: "interrupted"
        )
    }

    /// The recognizer stopped while the mic was held: the words stay in the box, unsaved.
    @Test func stoppedEarly() {
        assertScreenSnapshot(
            of: captureScreen(text: "A long thought", canSave: true, dictation: .failed(.stoppedEarly)),
            named: "stoppedEarly"
        )
    }

    /// Recognition failed: says so, and leaves the box as it was.
    @Test func recognitionFailed() {
        assertScreenSnapshot(
            of: captureScreen(text: "", canSave: false, dictation: .failed(.recognitionFailed)),
            named: "recognitionFailed"
        )
    }

    private func captureScreen(
        text: String,
        isOverLimit: Bool = false,
        canSave: Bool,
        saveResult: CaptureModel.SaveResult? = nil,
        dictation: CaptureModel.DictationState = .idle
    ) -> some View {
        NavigationStack {
            CaptureView(
                text: .constant(text),
                characterCount: text.count,
                characterLimit: CaptureModel.characterLimit,
                isOverLimit: isOverLimit,
                canSave: canSave,
                saveResult: saveResult,
                dictation: dictation,
                onSave: {},
                onMicPress: {},
                onMicRelease: {},
                onOpenSettings: {},
                onShowCaptures: {}
            )
        }
    }
}
