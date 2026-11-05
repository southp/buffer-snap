import BufferSnapCore
import Testing

@MainActor
struct CaptureModelDictationFailureTests {
    private func makeModel(
        speech: any SpeechTranscriber,
        store: any CaptureStore = InMemoryCaptureStore(),
        finalWordsTimeout: Duration = .seconds(3)
    ) -> CaptureModel {
        CaptureModel(store: store, speech: speech, finalWordsTimeout: finalWordsTimeout)
    }

    // MARK: Permission

    // The prompts take the finger off the button, so listening then would have no release to end it.
    @Test func theFirstPressAsksAndDoesNotListen() async {
        let speech = MockSpeechTranscriber(permission: .undetermined)
        let model = makeModel(speech: speech)

        await model.startDictation()

        #expect(await speech.requestCount == 1)
        #expect(await speech.startCount == 0)
        #expect(model.dictation == .idle)
    }

    @Test func theNextPressListensAndAsksNoMore() async {
        let speech = MockSpeechTranscriber(permission: .undetermined)
        let model = makeModel(speech: speech)
        await model.startDictation()

        await model.startDictation()

        #expect(await speech.requestCount == 1)
        #expect(model.dictation == .listening)
    }

    @Test(arguments: [
        (SpeechPermission.microphoneDenied, CaptureModel.DictationFailure.microphoneDenied),
        (.speechRecognitionDenied, .speechRecognitionDenied),
        (.restricted, .restricted),
    ])
    func refusingWhenAskedSaysWhy(answer: SpeechPermission, failure: CaptureModel.DictationFailure) async {
        let speech = MockSpeechTranscriber(permission: .undetermined, answer: answer)
        let model = makeModel(speech: speech)

        await model.startDictation()

        #expect(model.dictation == .failed(failure))
        #expect(await speech.startCount == 0)
    }

    @Test func aRefusedPermissionShowsBeforeTheMicIsTouched() async {
        let model = makeModel(speech: MockSpeechTranscriber(permission: .microphoneDenied))

        await model.refreshDictationPermission()

        #expect(model.dictation == .failed(.microphoneDenied))
    }

    @Test func typingAndSavingStillWorkWithPermissionRefused() async {
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: MockSpeechTranscriber(permission: .speechRecognitionDenied), store: store)
        await model.refreshDictationPermission()

        model.update(text: "Typed")
        #expect(model.dictation == .failed(.speechRecognitionDenied))
        #expect(model.canSave)
        await model.save()

        #expect(await store.all().map(\.text) == ["Typed"])
        #expect(model.dictation == .failed(.speechRecognitionDenied))
    }

    @Test func allowingItInSettingsClearsTheMessage() async {
        let speech = MockSpeechTranscriber(permission: .microphoneDenied, answer: .granted)
        let model = makeModel(speech: speech)
        await model.refreshDictationPermission()

        _ = await speech.requestPermission()
        await model.refreshDictationPermission()

        #expect(model.dictation == .idle)
    }

    @Test func refreshingKeepsOtherMessages() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech)
        await model.startDictation()
        await model.finishDictation()

        await model.refreshDictationPermission()

        #expect(model.dictation == .finished(.nothingHeard))
    }

    // MARK: Unavailable, interrupted, stopped

    @Test func recognitionBeingUnavailableSaysSoAndTypingWorks() async {
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: MockSpeechTranscriber(startError: .unavailable), store: store)

        await model.startDictation()
        #expect(model.dictation == .failed(.unavailable))

        model.update(text: "Typed")
        await model.save()
        #expect(await store.all().map(\.text) == ["Typed"])
    }

    // A call arriving keeps the words but saves nothing: the release that would have asked for it may never come.
    @Test func anInterruptionKeepsTheWordsUnsaved() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)

        await model.startDictation()
        await speech.hear("Before the call")
        await waitFor { model.text == "Before the call" }
        await speech.stopByItself(throwing: .interrupted)
        await waitFor { !model.isDictating }

        #expect(model.dictation == .failed(.interrupted))
        #expect(model.text == "Before the call")
        #expect(await store.all().isEmpty)
    }

    @Test func releasingAfterAnInterruptionStillSavesNothing() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        await model.startDictation()
        await speech.hear("Before the call")
        await waitFor { model.text == "Before the call" }
        await speech.stopByItself(throwing: .interrupted)
        await waitFor { !model.isDictating }

        await model.finishDictation()

        #expect(model.text == "Before the call")
        #expect(await store.all().isEmpty)
    }

    @Test func theAppLeavingWhileListeningKeepsTheWordsUnsaved() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        await model.startDictation()
        await speech.hear("Half a thought")
        await waitFor { model.text == "Half a thought" }

        await model.interruptDictation()

        #expect(model.dictation == .failed(.interrupted))
        #expect(model.text == "Half a thought")
        #expect(await speech.cancelCount == 1)
        #expect(await store.all().isEmpty)
    }

    // The time limit can arrive mid-sentence. Saving there would drop the rest of it without saying so.
    @Test func stoppingWhileHeldKeepsTheWordsUnsaved() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)

        await model.startDictation()
        await speech.hear("A long thought")
        await waitFor { model.text == "A long thought" }
        await speech.stopByItself()
        await waitFor { !model.isDictating }

        #expect(model.dictation == .failed(.stoppedEarly))
        #expect(model.text == "A long thought")
        #expect(await store.all().isEmpty)
    }

    @Test func recognitionFailingWithNothingHeardSaysSo() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech)

        await model.startDictation()
        await speech.stopByItself(throwing: .failed)
        await waitFor { !model.isDictating }

        #expect(model.dictation == .failed(.recognitionFailed))
    }

    @Test func holdingAgainAfterAStopAddsToTheWords() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        await model.startDictation()
        await speech.hear("First part")
        await waitFor { model.text == "First part" }
        await speech.stopByItself()
        await waitFor { !model.isDictating }

        await model.startDictation()
        await speech.hear("second part")
        await model.finishDictation()

        #expect(await store.all().map(\.text) == ["First part second part"])
    }

    // MARK: Clearing messages

    @Test func typingClearsAMessage() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech)
        await model.startDictation()
        await model.finishDictation()

        model.update(text: "T")

        #expect(model.dictation == .idle)
    }

    @Test func comingBackForgetsTheFinishedOutcome() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech)
        await model.startDictation()
        await speech.hear("An idea")
        await model.finishDictation()

        model.clearSaveResult()

        #expect(model.dictation == .idle)
        #expect(model.saveResult == nil)
    }
}
