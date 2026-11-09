import BufferSnapCore
import Foundation
import Testing

/// Asking for the microphone and speech recognition: only with the app on screen, and only until they're decided.
@MainActor
struct HandsFreeDictationPermissionTests {
    private func makeSession(speech: any SpeechTranscriber) -> HandsFreeDictationSession {
        HandsFreeDictationSession(
            speech: speech,
            store: InMemoryCaptureStore(),
            display: MockDictationDisplay(),
            keepAlive: MockDictationKeepAlive(),
            clock: ManualDictationClock()
        )
    }

    /// A press from outside the app can't ask, so it says so, and only opening the app does.
    @Test func aPressBeforeTheAppWasOpenedDoesntAsk() async {
        let speech = MockSpeechTranscriber(permission: .undetermined)
        let session = makeSession(speech: speech)

        await session.press()

        #expect(session.dictation.phase == .ended(.needsPermission))
        #expect(await speech.requestCount == 0)
    }

    /// The acceptance criterion: opening the app once is enough for the first press to dictate.
    @Test func openingTheAppOnceIsEnoughForTheFirstPress() async {
        let speech = MockSpeechTranscriber(permission: .undetermined)
        let session = makeSession(speech: speech)

        await session.askForPermissionIfNeeded()
        await session.press()

        #expect(await speech.requestCount == 1)
        #expect(await speech.startCount == 1)
        #expect(session.dictation.phase == .listening)
    }

    /// Every later time the app comes to the foreground, whatever the answer was.
    @Test(arguments: [
        SpeechPermission.granted, .microphoneDenied, .speechRecognitionDenied, .restricted,
    ])
    func itAsksOnlyOnce(answer: SpeechPermission) async {
        let speech = MockSpeechTranscriber(permission: .undetermined, answer: answer)
        let session = makeSession(speech: speech)

        await session.askForPermissionIfNeeded()
        await session.askForPermissionIfNeeded()

        #expect(await speech.requestCount == 1)
    }

    /// Someone who already decided, on an earlier launch, is never asked: iOS wouldn't show a prompt anyway.
    @Test(arguments: [
        SpeechPermission.granted, .microphoneDenied, .speechRecognitionDenied, .restricted,
    ])
    func itDoesntAskOnceDecided(permission: SpeechPermission) async {
        let speech = MockSpeechTranscriber(permission: permission)
        let session = makeSession(speech: speech)

        await session.askForPermissionIfNeeded()

        #expect(await speech.requestCount == 0)
    }

    /// Answering the first prompt brings the app back to the foreground while the second is still to come.
    @Test func comingBackWhileThePromptsAreUpDoesntAskTwice() async {
        let speech = HeldPermissionTranscriber()
        let session = makeSession(speech: speech)

        let first = Task {
            await session.askForPermissionIfNeeded()
        }
        await speech.waitForRequest()
        await session.askForPermissionIfNeeded()
        await speech.answer()
        await first.value

        #expect(await speech.requestCount == 1)
    }
}

/// A transcriber whose permission prompts stay up until the test answers them.
private actor HeldPermissionTranscriber: SpeechTranscriber {
    private(set) var requestCount = 0
    private var current = SpeechPermission.undetermined
    private var requested: CheckedContinuation<Void, Never>?
    private var answered: CheckedContinuation<Void, Never>?

    func permission() -> SpeechPermission {
        current
    }

    func requestPermission() async -> SpeechPermission {
        requestCount += 1
        requested?.resume()
        requested = nil
        await withCheckedContinuation { answered = $0 }
        current = .granted
        return current
    }

    func waitForRequest() async {
        if requestCount == 0 {
            await withCheckedContinuation { requested = $0 }
        }
    }

    func answer() {
        answered?.resume()
        answered = nil
    }

    func start() async throws -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func finish() {}

    func cancel() {}
}
