import BufferSnapCore
import Foundation
import Testing

/// A press when there's no Live Activity to show it on: iOS ends the app if the mic is on then.
@MainActor
struct HandsFreeDictationLiveActivityTests {
    private let display = MockDictationDisplay()
    private let clock = ManualDictationClock()

    private func makeSession(speech: MockSpeechTranscriber) -> HandsFreeDictationSession {
        HandsFreeDictationSession(
            speech: speech,
            store: InMemoryCaptureStore(),
            display: display,
            keepAlive: MockDictationKeepAlive(),
            clock: clock
        )
    }

    @Test func withoutALiveActivityTheMicStaysOffAndThePressNeedsTheApp() async {
        let speech = MockSpeechTranscriber()
        display.canShow = false
        let session = makeSession(speech: speech)

        let result = await session.press()

        #expect(result == .needsTheApp)
        #expect(await speech.startCount == 0)
        #expect(session.dictation.phase == .ended(.couldNotListen))
    }

    @Test func aPressThatListensDoesntNeedTheApp() async {
        let speech = MockSpeechTranscriber()
        let session = makeSession(speech: speech)

        let result = await session.press()

        #expect(result == .done)
        #expect(await speech.startCount == 1)
    }

    @Test func aRefusedPermissionWithoutALiveActivityNeedsTheApp() async {
        let speech = MockSpeechTranscriber(permission: .microphoneDenied)
        display.canShow = false
        let session = makeSession(speech: speech)

        let result = await session.press()

        #expect(result == .needsTheApp)
        #expect(await speech.startCount == 0)
    }

    @Test func aPressCanListenOnceLiveActivitiesAreBackOn() async {
        let speech = MockSpeechTranscriber()
        display.canShow = false
        let session = makeSession(speech: speech)
        await session.press()
        clock.advance(by: 4)
        await waitFor { session.dictation.phase == .idle }

        display.canShow = true
        let result = await session.press()

        #expect(result == .done)
        #expect(await speech.startCount == 1)
    }
}
