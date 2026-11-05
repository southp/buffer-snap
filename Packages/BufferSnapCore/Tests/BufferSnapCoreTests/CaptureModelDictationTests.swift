import BufferSnapCore
import Testing

@MainActor
struct CaptureModelDictationTests {
    private func makeModel(
        speech: any SpeechTranscriber,
        store: any CaptureStore = InMemoryCaptureStore(),
        finalWordsTimeout: Duration = .seconds(3)
    ) -> CaptureModel {
        CaptureModel(store: store, speech: speech, finalWordsTimeout: finalWordsTimeout)
    }

    // MARK: Holding, speaking, releasing

    @Test func startsIdle() {
        let model = makeModel(speech: MockSpeechTranscriber())

        #expect(model.dictation == .idle)
        #expect(!model.isDictating)
    }

    @Test func pressingListensAndShowsLiveText() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech)

        await model.startDictation()
        #expect(model.dictation == .listening)

        await speech.hear("Hello")
        await waitFor { model.text == "Hello" }
        await speech.hear("Hello there")
        await waitFor { model.text == "Hello there" }
        #expect(model.dictation == .listening)
    }

    @Test func releasingSavesTheWordsAsAPendingTextCapture() async throws {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)

        await model.startDictation()
        await speech.hear("An idea")
        await model.finishDictation()

        let capture = try #require(await store.all().first)
        #expect(capture.kind == .text)
        #expect(capture.status == .pending)
        #expect(capture.text == "An idea")
        #expect(model.text.isEmpty)
        #expect(model.saveResult == .saved)
        #expect(model.dictation == .finished(.saved))
    }

    @Test func releaseSavesTheFinalWordsNotTheLastPartial() async {
        let speech = MockSpeechTranscriber(finalWords: "An idea, finished.")
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)

        await model.startDictation()
        await speech.hear("An idear")
        await model.finishDictation()

        #expect(await store.all().map(\.text) == ["An idea, finished."])
    }

    @Test func isFinishingBetweenReleaseAndTheFinalWords() async {
        let speech = MockSpeechTranscriber(endsOnFinish: false)
        let model = makeModel(speech: speech)
        await model.startDictation()
        await speech.hear("An idea")

        let release = Task {
            await model.finishDictation()
        }
        await waitFor { model.dictation == .finishing }
        #expect(!model.canSave)

        await speech.stopByItself()
        await release.value
        #expect(model.dictation == .finished(.saved))
    }

    // A recognizer that never delivers its last words mustn't leave the screen stuck, or lose what it heard.
    @Test func savesWhatWasHeardIfTheFinalWordsNeverCome() async {
        let speech = MockSpeechTranscriber(endsOnFinish: false)
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store, finalWordsTimeout: .milliseconds(10))

        await model.startDictation()
        await speech.hear("An idea")
        await waitFor { model.text == "An idea" }
        await model.finishDictation()

        #expect(await store.all().map(\.text) == ["An idea"])
        #expect(model.dictation == .finished(.saved))
        #expect(await speech.cancelCount == 1)
    }

    // Live text can reach the box before the error does, and the words are worth more than the error.
    @Test func aLateErrorStillSavesWhatWasHeard() async {
        let speech = MockSpeechTranscriber(endsOnFinish: false)
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)

        await model.startDictation()
        await speech.hear("An idea")
        await waitFor { model.text == "An idea" }
        let release = Task {
            await model.finishDictation()
        }
        await waitFor { model.dictation == .finishing }
        await speech.stopByItself(throwing: .failed)
        await release.value

        #expect(await store.all().map(\.text) == ["An idea"])
    }

    // MARK: Nothing heard

    @Test func releasingWithNothingHeardSavesNothing() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)

        await model.startDictation()
        await model.finishDictation()

        #expect(await store.all().isEmpty)
        #expect(model.saveResult == nil)
        #expect(model.dictation == .finished(.nothingHeard))
    }

    // An accidental tap can arrive before the audio has even started.
    @Test func aQuickTapStopsListeningAndSavesNothing() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        await speech.setOnStart { @MainActor in
            await model.finishDictation()
        }

        await model.startDictation()

        #expect(model.dictation == .finished(.nothingHeard))
        #expect(await speech.cancelCount == 1)
        #expect(await store.all().isEmpty)
    }

    // The draft was typed on purpose, and holding the mic for nothing isn't asking to save it.
    @Test func aTapWithATypedDraftKeepsItUnsaved() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        model.update(text: "Typed")

        await model.startDictation()
        await model.finishDictation()

        #expect(model.text == "Typed")
        #expect(await store.all().isEmpty)
        #expect(model.dictation == .finished(.nothingHeard))
    }

    @Test func aFinalWithNoSpeechErrorCountsAsNothingHeard() async {
        let speech = MockSpeechTranscriber(endsOnFinish: false)
        let model = makeModel(speech: speech)

        await model.startDictation()
        await speech.stopByItself(throwing: .noSpeech)
        await waitFor { !model.isDictating }

        #expect(model.dictation == .finished(.nothingHeard))
    }

    @Test func emptyFinalWordsLeaveTheBoxEmpty() async {
        let speech = MockSpeechTranscriber(finalWords: "")
        let model = makeModel(speech: speech)

        await model.startDictation()
        await model.finishDictation()

        #expect(model.text.isEmpty)
    }

    // MARK: Over the limit

    // A long ramble mustn't lose words or vanish: it waits in the box to be cut down (42-over-limit-dictation).
    @Test func overTheLimitLandsInTheBoxUnsaved() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        let tooLong = String(repeating: "a", count: CaptureModel.characterLimit + 1)

        await model.startDictation()
        await speech.hear(tooLong)
        await model.finishDictation()

        #expect(model.text == tooLong)
        #expect(model.isOverLimit)
        #expect(await store.all().isEmpty)
        #expect(model.dictation == .finished(.tooLong))
    }

    @Test func editingAnOverLimitDictationDownLetsItSave() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        await model.startDictation()
        await speech.hear(String(repeating: "a", count: CaptureModel.characterLimit + 1))
        await model.finishDictation()

        model.update(text: "Short now")
        #expect(model.dictation == .idle)
        await model.save()

        #expect(await store.all().map(\.text) == ["Short now"])
    }

    // MARK: Adding to a draft

    @Test func wordsGoAfterATypedDraftAndSaveTogether() async {
        let speech = MockSpeechTranscriber()
        let store = InMemoryCaptureStore()
        let model = makeModel(speech: speech, store: store)
        model.update(text: "Typed")

        await model.startDictation()
        await speech.hear("and spoken")
        await waitFor { model.text == "Typed and spoken" }
        await model.finishDictation()

        #expect(await store.all().map(\.text) == ["Typed and spoken"])
    }

    @Test func typingWhileListeningIsIgnored() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech)
        await model.startDictation()
        await speech.hear("Spoken")
        await waitFor { model.text == "Spoken" }

        model.update(text: "Typed over")

        #expect(model.text == "Spoken")
        #expect(!model.canSave)
    }

    @Test func aFailedStoreKeepsTheWordsAndSaysSo() async {
        let speech = MockSpeechTranscriber()
        let model = makeModel(speech: speech, store: ReadOnlyCaptureStore(captures: []))

        await model.startDictation()
        await speech.hear("An idea")
        await model.finishDictation()

        #expect(model.text == "An idea")
        #expect(model.saveResult == .failed)
        #expect(model.dictation == .finished(.saveFailed))
        #expect(model.canSave)
    }
}
