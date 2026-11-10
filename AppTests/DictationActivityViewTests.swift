import BufferSnapCore
import SwiftUI
import Testing

/// The dictation's Live Activity on the Lock Screen, rendered to AppTests/__Snapshots__/DictationActivityViewTests/ at
/// its size on the pinned iPhone 16, on the paper `DictationLiveActivity` asks the system for. These show the activity,
/// not a whole Lock Screen.
@MainActor
struct DictationActivityViewTests {
    private let startedAt = Capture.samplesReferenceDate

    /// Just pressed: the timer, Stop, and a prompt.
    @Test func listening() {
        assertScreenSnapshot(of: activity(.listening, pausedAfter: 2), named: "listening")
    }

    /// The words as they're heard, with the timer frozen 18 seconds in.
    @Test func listeningWithWords() {
        let words = "Post idea: the worst tofu I ever had, in the finest restaurant in town"
        assertScreenSnapshot(of: activity(.listening, words: words, pausedAfter: 18), named: "listeningWithWords")
        assertScreenSnapshot(
            of: activity(.listening, words: words, pausedAfter: 18), named: "listeningWithWords-dark", appearance: .dark
        )
    }

    /// Stopped: no timer and no Stop, while the last words come in.
    @Test func finishing() {
        assertScreenSnapshot(of: activity(.finishing, words: "Post idea: the worst tofu"), named: "finishing")
    }

    /// Saved, with what was saved, and no timer: the spike's kept running here.
    @Test func saved() {
        assertScreenSnapshot(of: activity(.saved, words: "Post idea: the worst tofu"), named: "saved")
        assertScreenSnapshot(
            of: activity(.saved, words: "Post idea: the worst tofu"), named: "saved-dark", appearance: .dark)
    }

    @Test func nothingHeard() {
        assertScreenSnapshot(of: activity(.nothingHeard), named: "nothingHeard")
    }

    /// The mic or speech recognition isn't allowed, or wasn't asked for yet.
    @Test func needsPermission() {
        assertScreenSnapshot(of: activity(.needsPermission), named: "needsPermission")
        assertScreenSnapshot(of: activity(.needsPermission), named: "needsPermission-dark", appearance: .dark)
    }

    @Test func couldNotListen() {
        assertScreenSnapshot(of: activity(.couldNotListen), named: "couldNotListen")
    }

    @Test func couldNotSave() {
        assertScreenSnapshot(of: activity(.couldNotSave), named: "couldNotSave")
    }

    /// A Lock Screen Live Activity on iPhone 16 is the screen's width less 16 points each side.
    private func activity(
        _ phase: DictationStatus.Phase,
        words: String = "",
        pausedAfter seconds: TimeInterval = 0
    ) -> some View {
        let status = DictationStatus(
            phase: phase,
            words: words,
            startedAt: startedAt,
            endsAt: startedAt + HandsFreeDictation.timeLimit
        )
        return DictationActivityView(status: status, timerPausedAt: startedAt + seconds)
            .frame(width: 361)
            .background(Theme.paper, in: .rect(cornerRadius: 22))
    }
}
