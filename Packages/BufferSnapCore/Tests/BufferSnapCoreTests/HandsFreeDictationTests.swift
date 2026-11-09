import BufferSnapCore
import Foundation
import Testing

/// The rules of dictating outside the app, with the time given explicitly.
struct HandsFreeDictationTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start + seconds
    }

    /// A dictation that's been pressed and is listening, as of `start`.
    private func listening() -> HandsFreeDictation {
        var dictation = HandsFreeDictation()
        _ = dictation.press(at: start)
        _ = dictation.didStartListening(at: start)
        return dictation
    }

    // MARK: Starting and stopping

    @Test func aPressFromIdleStarts() {
        var dictation = HandsFreeDictation()

        #expect(dictation.press(at: start) == .start)
        #expect(dictation.phase == .starting)
        #expect(dictation.status?.phase == .listening)
    }

    @Test func listensOnceTheMicIsOn() {
        var dictation = HandsFreeDictation()
        _ = dictation.press(at: start)

        #expect(dictation.didStartListening(at: at(0.2)) == .none)
        #expect(dictation.phase == .listening)
    }

    @Test func aSecondPressWhileListeningStops() {
        var dictation = listening()

        #expect(dictation.press(at: at(5)) == .finish)
        #expect(dictation.phase == .finishing)
    }

    @Test func stopFromTheLiveActivityStops() {
        var dictation = listening()

        #expect(dictation.stopTapped() == .finish)
        #expect(dictation.phase == .finishing)
    }

    @Test func stopNeverStartsAnything() {
        var dictation = HandsFreeDictation()

        #expect(dictation.stopTapped() == .none)
        #expect(dictation.phase == .idle)
    }

    // The bug the spike found on the Action button: whatever the timing, a press mustn't start a second dictation.

    @Test func aPressWhileFinishingIsIgnored() {
        var dictation = listening()
        _ = dictation.press(at: at(5))

        #expect(dictation.press(at: at(5.5)) == .none)
        #expect(dictation.phase == .finishing)
    }

    @Test func aPressWhileSavingIsIgnored() {
        var dictation = listening()
        dictation.heard("An idea", at: at(1))
        _ = dictation.press(at: at(2))
        _ = dictation.listeningEnded(failed: false, at: at(2.5))

        #expect(dictation.press(at: at(2.6)) == .none)
        #expect(dictation.phase == .saving)
    }

    @Test func aPressWhileStartingStopsOnceTheMicIsOn() {
        var dictation = HandsFreeDictation()
        _ = dictation.press(at: start)

        #expect(dictation.press(at: at(0.1)) == .none)
        #expect(dictation.didStartListening(at: at(0.3)) == .finish)
        #expect(dictation.phase == .finishing)
    }

    @Test func stopWhileStartingStopsOnceTheMicIsOn() {
        var dictation = HandsFreeDictation()
        _ = dictation.press(at: start)

        #expect(dictation.stopTapped() == .none)
        #expect(dictation.didStartListening(at: at(0.3)) == .finish)
    }

    // A press meant to stop can land just after silence stopped it.
    @Test func aPressWhileTheOutcomeShowsIsIgnored() {
        var dictation = listening()
        dictation.heard("An idea", at: at(1))
        _ = dictation.tick(at: at(4))
        _ = dictation.listeningEnded(failed: false, at: at(4.2))
        dictation.saveEnded(succeeded: true, at: at(4.3))

        #expect(dictation.press(at: at(4.5)) == .none)
        #expect(dictation.phase == .ended(.saved))
    }

    @Test func aPressAfterTheOutcomeStartsANewDictation() {
        var dictation = listening()
        _ = dictation.press(at: at(1))
        _ = dictation.listeningEnded(failed: false, at: at(1))

        #expect(dictation.press(at: at(1 + HandsFreeDictation.outcomeDuration)) == .start)
        #expect(dictation.words.isEmpty)
        #expect(dictation.startedAt == at(4))
    }

    // MARK: Stopping by itself

    @Test func stopsAfterThreeSecondsOfSilenceOnceSomethingsBeenHeard() {
        var dictation = listening()
        dictation.heard("An idea", at: at(2))

        #expect(dictation.nextDeadline == at(5))
        #expect(dictation.tick(at: at(4.9)) == .none)
        #expect(dictation.tick(at: at(5)) == .finish)
    }

    @Test func newWordsPushTheSilenceBack() {
        var dictation = listening()
        dictation.heard("An", at: at(2))
        dictation.heard("An idea", at: at(4))

        #expect(dictation.tick(at: at(5)) == .none)
        #expect(dictation.nextDeadline == at(7))
    }

    @Test func silenceBeforeAnyWordsDoesntStop() {
        var dictation = listening()

        #expect(dictation.tick(at: at(10)) == .none)
        #expect(dictation.nextDeadline == at(HandsFreeDictation.timeLimit))
    }

    @Test func blankWordsDontCountAsHeard() {
        var dictation = listening()
        dictation.heard(" ", at: at(1))

        #expect(dictation.tick(at: at(5)) == .none)
    }

    @Test func stopsAtSixtySeconds() {
        var dictation = listening()
        dictation.heard("On and on", at: at(59))

        #expect(dictation.tick(at: at(59.9)) == .none)
        #expect(dictation.tick(at: at(60)) == .finish)
    }

    // MARK: How it ends

    @Test func savesTheTrimmedWords() {
        var dictation = listening()
        dictation.heard(" An idea ", at: at(1))
        _ = dictation.stopTapped()

        #expect(dictation.listeningEnded(failed: false, at: at(2)) == .save("An idea"))
        dictation.saveEnded(succeeded: true, at: at(2.1))
        #expect(dictation.phase == .ended(.saved))
        #expect(dictation.status?.phase == .saved)
    }

    @Test func theLastWordsCountWhileFinishing() {
        var dictation = listening()
        dictation.heard("An idear", at: at(1))
        _ = dictation.stopTapped()
        dictation.heard("An idea.", at: at(1.5))

        #expect(dictation.listeningEnded(failed: false, at: at(2)) == .save("An idea."))
    }

    @Test func nothingHeardSavesNothing() {
        var dictation = listening()
        _ = dictation.stopTapped()

        #expect(dictation.listeningEnded(failed: false, at: at(2)) == .none)
        #expect(dictation.phase == .ended(.nothingHeard))
    }

    @Test func aFailureWithNothingHeardSaysSo() {
        var dictation = listening()

        #expect(dictation.listeningEnded(failed: true, at: at(2)) == .none)
        #expect(dictation.phase == .ended(.couldNotListen))
    }

    @Test func aFailureAfterWordsStillSavesThem() {
        var dictation = listening()
        dictation.heard("An idea", at: at(1))

        #expect(dictation.listeningEnded(failed: true, at: at(2)) == .save("An idea"))
    }

    @Test func aFailedSaveSaysSo() {
        var dictation = listening()
        dictation.heard("An idea", at: at(1))
        _ = dictation.listeningEnded(failed: false, at: at(2))
        dictation.saveEnded(succeeded: false, at: at(2.1))

        #expect(dictation.phase == .ended(.couldNotSave))
    }

    @Test(arguments: [
        HandsFreeDictation.Outcome.needsPermission, .couldNotListen,
    ])
    func whatStopsItStartingIsItsOutcome(outcome: HandsFreeDictation.Outcome) {
        var dictation = HandsFreeDictation()
        _ = dictation.press(at: start)
        dictation.couldNotStart(outcome, at: at(0.1))

        #expect(dictation.phase == .ended(outcome))
        #expect(dictation.status?.isListening == false)
    }

    @Test func theOutcomeGoesAwayAfterThreeSeconds() {
        var dictation = listening()
        _ = dictation.stopTapped()
        _ = dictation.listeningEnded(failed: false, at: at(2))

        #expect(dictation.nextDeadline == at(5))
        #expect(dictation.tick(at: at(4.9)) == .none)
        #expect(dictation.tick(at: at(5)) == .dismiss)
        #expect(dictation.phase == .idle)
        #expect(dictation.status == nil)
    }

    // MARK: What the Live Activity shows

    // The spike's countdown kept running after "Saved". Only listening may show one.
    @Test func onlyListeningShowsACountdown() {
        var dictation = listening()
        #expect(dictation.status?.isListening == true)
        #expect(dictation.status?.endsAt == at(HandsFreeDictation.timeLimit))

        dictation.heard("An idea", at: at(1))
        _ = dictation.stopTapped()
        #expect(dictation.status?.phase == .finishing)
        #expect(dictation.status?.isListening == false)
        #expect(dictation.nextDeadline == nil)
    }

    @Test func theStatusCarriesTheWords() {
        var dictation = listening()
        dictation.heard("An idea", at: at(1))

        #expect(dictation.status?.words == "An idea")
    }
}
