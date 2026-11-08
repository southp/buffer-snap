import BufferSnapCore
import Foundation
import Synchronization
import Testing

/// Dictating outside the app, end to end: the session on a mock transcriber, store, Live Activity and clock.
@MainActor
struct HandsFreeDictationSessionTests {
    private let speech: MockSpeechTranscriber
    private let store: any CaptureStore
    private let display = MockDictationDisplay()
    private let keepAlive = MockDictationKeepAlive()
    private let clock = ManualDictationClock()
    private let sends = Counter()

    init(
        speech: MockSpeechTranscriber = MockSpeechTranscriber(),
        store: any CaptureStore = InMemoryCaptureStore()
    ) {
        self.speech = speech
        self.store = store
    }

    private func makeSession(isSignedIn: Bool = true) -> HandsFreeDictationSession {
        HandsFreeDictationSession(
            speech: speech,
            store: store,
            display: display,
            keepAlive: keepAlive,
            clock: clock,
            isSignedIn: { isSignedIn },
            onSaved: { [sends] in
                sends.increment()
            }
        )
    }

    /// Presses, and waits for `words` to reach the Live Activity.
    private func listen(_ session: HandsFreeDictationSession, hearing words: String) async {
        await session.press()
        await speech.hear(words)
        await waitFor { display.shown.last?.words == words }
    }

    // MARK: Start and stop

    @Test func aPressListensAndShowsTheLiveActivity() async {
        let session = makeSession()

        await session.press()

        #expect(session.dictation.phase == .listening)
        #expect(await speech.startCount == 1)
        #expect(display.shown.last?.phase == .listening)
    }

    @Test func theWordsShowAsTheyreHeard() async {
        let session = makeSession()
        await session.press()

        await speech.hear("An")
        await waitFor { display.shown.last?.words == "An" }
        await speech.hear("An idea")
        await waitFor { display.shown.last?.words == "An idea" }
    }

    @Test func aSecondPressSavesTheWordsAsAPendingTextCapture() async throws {
        let session = makeSession()
        await listen(session, hearing: "An idea")

        await session.press()
        await waitFor { session.dictation.phase == .ended(.saved) }

        let capture = try #require(await store.all().first)
        #expect(capture.kind == .text)
        #expect(capture.status == .pending)
        #expect(capture.text == "An idea")
        #expect(display.shown.last?.phase == .saved)
        #expect(await speech.startCount == 1)
    }

    @Test func stopFromTheLiveActivitySaves() async throws {
        let session = makeSession()
        await listen(session, hearing: "An idea")

        await session.stop()
        await waitFor { session.dictation.phase == .ended(.saved) }

        #expect(try await store.all().map(\.text) == ["An idea"])
    }

    @Test func eachSaveIsHandedOnToBeSent() async {
        let session = makeSession()
        await listen(session, hearing: "An idea")

        await session.press()

        await waitFor { sends.value == 1 }
    }

    // The spike's Action button bug: pressing again while it finished started a second dictation.
    @Test func pressesWhileFinishingNeverStartAnother() async {
        let speech = MockSpeechTranscriber(endsOnFinish: false)
        let fixture = HandsFreeDictationSessionTests(speech: speech)
        let session = fixture.makeSession()
        await fixture.listen(session, hearing: "An idea")

        await session.press()
        await session.press()
        await session.press()

        #expect(session.dictation.phase == .finishing)
        #expect(await speech.startCount == 1)
    }

    @Test func aPressWhileStartingStopsOnceTheMicIsOn() async {
        let session = makeSession()
        await speech.setOnStart {
            await session.press()
        }

        await session.press()
        await waitFor { session.dictation.phase == .ended(.nothingHeard) }

        #expect(await speech.startCount == 1)
    }

    @Test func aPressWhileTheOutcomeShowsIsIgnored() async {
        let session = makeSession()
        await listen(session, hearing: "An idea")
        await session.press()
        await waitFor { session.dictation.phase == .ended(.saved) }

        await session.press()

        #expect(session.dictation.phase == .ended(.saved))
        #expect(await speech.startCount == 1)
    }

    // MARK: Stopping by itself

    @Test func stopsAfterThreeSecondsOfSilence() async throws {
        let session = makeSession()
        await listen(session, hearing: "An idea")

        clock.advance(by: 2.9)
        try? await Task.sleep(for: .milliseconds(20))
        #expect(session.dictation.phase == .listening)
        clock.advance(by: 0.1)

        await waitFor { session.dictation.phase == .ended(.saved) }
        #expect(try await store.all().map(\.text) == ["An idea"])
    }

    @Test func stopsAtSixtySeconds() async {
        let session = makeSession()
        await session.press()

        clock.advance(by: HandsFreeDictation.timeLimit)

        await waitFor { session.dictation.phase == .ended(.nothingHeard) }
    }

    @Test func savesWhatWasHeardIfTheLastWordsNeverCome() async throws {
        let speech = MockSpeechTranscriber(endsOnFinish: false)
        let fixture = HandsFreeDictationSessionTests(speech: speech)
        let session = fixture.makeSession()
        await fixture.listen(session, hearing: "An idea")
        await session.press()

        fixture.clock.advance(by: 3)

        await waitFor { session.dictation.phase == .ended(.saved) }
        #expect(try await fixture.store.all().map(\.text) == ["An idea"])
        #expect(await speech.cancelCount == 1)
    }

    @Test func savesTheLastWordsNotTheLastPartial() async throws {
        let speech = MockSpeechTranscriber(finalWords: "An idea, finished.")
        let fixture = HandsFreeDictationSessionTests(speech: speech)
        let session = fixture.makeSession()
        await fixture.listen(session, hearing: "An idear")

        await session.press()

        await waitFor { session.dictation.phase == .ended(.saved) }
        #expect(try await fixture.store.all().map(\.text) == ["An idea, finished."])
    }

    // MARK: How it ends

    @Test func nothingHeardSavesNothing() async throws {
        let session = makeSession()
        await session.press()

        await session.press()

        await waitFor { session.dictation.phase == .ended(.nothingHeard) }
        #expect(try await store.all().isEmpty)
        #expect(display.shown.last?.phase == .nothingHeard)
        #expect(sends.value == 0)
    }

    @Test func wordsHeardBeforeAFailureAreStillSaved() async throws {
        let session = makeSession()
        await listen(session, hearing: "An idea")

        await speech.stopByItself(throwing: .interrupted)

        await waitFor { session.dictation.phase == .ended(.saved) }
        #expect(try await store.all().map(\.text) == ["An idea"])
    }

    @Test func aMicThatWontStartSaysSo() async {
        let fixture = HandsFreeDictationSessionTests(speech: MockSpeechTranscriber(startError: .unavailable))
        let session = fixture.makeSession()

        await session.press()

        #expect(session.dictation.phase == .ended(.couldNotListen))
        #expect(fixture.display.shown.last?.phase == .couldNotListen)
    }

    @Test func aFailedSaveSaysSo() async {
        let fixture = HandsFreeDictationSessionTests(store: ReadOnlyCaptureStore(captures: []))
        let session = fixture.makeSession()
        await fixture.listen(session, hearing: "An idea")

        await session.press()

        await waitFor { session.dictation.phase == .ended(.couldNotSave) }
        #expect(fixture.sends.value == 0)
    }

    // The spike's countdown kept running after "Saved". Nothing after the stop may show one.
    @Test func nothingShowsACountdownOnceItsStopped() async {
        let session = makeSession()
        await listen(session, hearing: "An idea")
        let shownWhileListening = display.shown.count

        await session.press()
        await waitFor { session.dictation.phase == .ended(.saved) }

        let afterTheStop = display.shown.dropFirst(shownWhileListening)
        #expect(afterTheStop.map(\.phase) == [.finishing, .saved])
        #expect(afterTheStop.allSatisfy { !$0.isListening })
    }

    @Test func theLiveActivityGoesAwayThreeSecondsAfterTheOutcome() async {
        let session = makeSession()
        await listen(session, hearing: "An idea")
        await session.press()
        await waitFor { session.dictation.phase == .ended(.saved) }
        #expect(display.dismissCount == 0)

        clock.advance(by: HandsFreeDictation.outcomeDuration)

        await waitFor { display.dismissCount == 1 }
        #expect(session.dictation.phase == .idle)
    }

    @Test func keepsTheProcessAwakeFromTheStopUntilItsAllDone() async {
        let session = makeSession()
        await listen(session, hearing: "An idea")
        #expect(!keepAlive.isHolding)

        await session.press()
        #expect(keepAlive.isHolding)
        await waitFor { session.dictation.phase == .ended(.saved) }
        clock.advance(by: HandsFreeDictation.outcomeDuration)

        await waitFor { !keepAlive.isHolding }
        #expect(keepAlive.beginCount == 1)
    }

    @Test func aNewDictationCanStartOnceTheOutcomeIsGone() async {
        let session = makeSession()
        await session.press()
        await session.press()
        await waitFor { session.dictation.phase == .ended(.nothingHeard) }
        clock.advance(by: HandsFreeDictation.outcomeDuration)
        await waitFor { session.dictation.phase == .idle }

        await session.press()

        #expect(session.dictation.phase == .listening)
        #expect(await speech.startCount == 2)
    }

    // MARK: What stops it listening at all

    @Test(arguments: [SpeechPermission.microphoneDenied, .speechRecognitionDenied, .restricted])
    func aRefusedPermissionSaysToOpenTheApp(permission: SpeechPermission) async {
        let fixture = HandsFreeDictationSessionTests(speech: MockSpeechTranscriber(permission: permission))
        let session = fixture.makeSession()

        await session.press()

        #expect(session.dictation.phase == .ended(.needsPermission))
        #expect(fixture.display.shown.map(\.phase) == [.needsPermission])
        #expect(await fixture.speech.startCount == 0)
        #expect(!session.needsPermissionPrompt)
    }

    // Only the app on screen can ask, so it asks next time it's opened.
    @Test func aPermissionNotAskedForYetIsAskedForInTheApp() async {
        let fixture = HandsFreeDictationSessionTests(speech: MockSpeechTranscriber(permission: .undetermined))
        let session = fixture.makeSession()

        await session.press()
        #expect(session.dictation.phase == .ended(.needsPermission))
        #expect(await fixture.speech.requestCount == 0)

        await session.askForPermissionIfNeeded()
        await session.askForPermissionIfNeeded()
        #expect(await fixture.speech.requestCount == 1)
    }

    @Test func theAppDoesntAskForPermissionUnprompted() async {
        let session = makeSession()

        await session.askForPermissionIfNeeded()

        #expect(await speech.requestCount == 0)
    }

    @Test func signedOutDoesntListen() async {
        let session = makeSession(isSignedIn: false)

        await session.press()

        #expect(session.dictation.phase == .ended(.signedOut))
        #expect(display.shown.map(\.phase) == [.signedOut])
        #expect(await speech.startCount == 0)
    }
}

/// Counts calls from any task.
final class Counter: Sendable {
    private let count = Mutex(0)

    var value: Int {
        count.withLock { $0 }
    }

    func increment() {
        count.withLock { $0 += 1 }
    }
}
