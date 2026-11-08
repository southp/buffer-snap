import BufferSnapCore
import Testing

/// What happens after a dictation outside the app is saved: it's handed on to be sent, with the app kept awake.
@MainActor
struct HandsFreeDictationSendingTests {
    private let speech = MockSpeechTranscriber()
    private let display = MockDictationDisplay()
    private let keepAlive = MockDictationKeepAlive()
    private let clock = ManualDictationClock()

    /// Sending can outlast the outcome on screen, and iOS must not suspend the app halfway through a request.
    @Test func staysAwakeUntilTheSendReturns() async {
        let send = Gate()
        let session = HandsFreeDictationSession(
            speech: speech,
            store: InMemoryCaptureStore(),
            display: display,
            keepAlive: keepAlive,
            clock: clock,
            onSaved: {
                await send.wait()
            }
        )
        await session.press()
        await speech.hear("An idea")
        await waitFor { display.shown.last?.words == "An idea" }

        await session.press()
        await waitFor { session.dictation.phase == .ended(.saved) }
        clock.advance(by: HandsFreeDictation.outcomeDuration)
        await waitFor { session.dictation.phase == .idle }
        #expect(keepAlive.isHolding)

        await send.open()
        await waitFor { !keepAlive.isHolding }
    }
}

/// Holds whoever waits on it until the test opens it.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters = []
    }
}
