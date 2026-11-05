import BufferSnapCore
import Foundation
import Testing

@MainActor
struct CaptureModelTests {
    private func makeModel(store: any CaptureStore = InMemoryCaptureStore(), text: String = "") -> CaptureModel {
        let model = CaptureModel(store: store, speech: MockSpeechTranscriber())
        model.update(text: text)
        return model
    }

    @Test func startsEmptyAndCannotSave() {
        let model = makeModel()

        #expect(model.text.isEmpty)
        #expect(model.characterCount == 0)
        #expect(model.saveResult == nil)
        #expect(!model.canSave)
    }

    @Test func whitespaceOnlyCannotSave() async {
        let store = InMemoryCaptureStore()
        let model = makeModel(store: store, text: " \n\t ")

        await model.save()

        #expect(!model.canSave)
        #expect(await store.all().isEmpty)
    }

    @Test func saveAddsAPendingTextCaptureAndClearsTheDraft() async throws {
        let store = InMemoryCaptureStore()
        let model = makeModel(store: store, text: "Idea for Friday's post")

        await model.save()

        let captures = await store.all()
        let capture = try #require(captures.first)
        #expect(captures.count == 1)
        #expect(capture.kind == .text)
        #expect(capture.status == .pending)
        #expect(capture.text == "Idea for Friday's post")
        #expect(model.text.isEmpty)
        #expect(model.saveResult == .saved)
    }

    @Test func saveTrimsSurroundingWhitespace() async {
        let store = InMemoryCaptureStore()
        let model = makeModel(store: store, text: "\n  Two\nlines  \n")

        await model.save()

        #expect(await store.all().map(\.text) == ["Two\nlines"])
    }

    @Test func exactlyAtTheLimitCanSave() async {
        let store = InMemoryCaptureStore()
        let model = makeModel(store: store, text: String(repeating: "a", count: CaptureModel.characterLimit))

        #expect(model.characterCount == 300)
        #expect(!model.isOverLimit)
        #expect(model.canSave)

        await model.save()

        #expect(await store.all().count == 1)
    }

    // Saving nothing beats saving less than was typed, so an over-long draft waits to be edited.
    @Test func overTheLimitCannotSaveAndKeepsTheDraft() async {
        let store = InMemoryCaptureStore()
        let tooLong = String(repeating: "a", count: CaptureModel.characterLimit + 1)
        let model = makeModel(store: store, text: tooLong)

        await model.save()

        #expect(model.isOverLimit)
        #expect(!model.canSave)
        #expect(model.text == tooLong)
        #expect(model.saveResult == nil)
        #expect(await store.all().isEmpty)
    }

    @Test func whitespaceDoesNotCountTowardTheLimit() {
        let atLimit = String(repeating: "a", count: CaptureModel.characterLimit)
        let model = makeModel(text: atLimit + "\n\n")

        #expect(model.characterCount == CaptureModel.characterLimit)
        #expect(model.canSave)
    }

    // Each of these is one character to the person typing it, though more to the machine.
    @Test func charactersCountAsPeopleSeeThem() {
        let model = makeModel(text: "👩‍💻é台")

        #expect(model.characterCount == 3)
    }

    @Test func failedSaveKeepsTheDraftAndCanBeRetried() async {
        let model = makeModel(store: ReadOnlyCaptureStore(captures: []), text: "An idea")

        await model.save()

        #expect(model.text == "An idea")
        #expect(model.saveResult == .failed)
        #expect(model.canSave)
    }

    // The store throws on a file it can't decode, and the idea mustn't be lost to it.
    @Test func undecodableFileKeepsTheDraftAndTheFile() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contents = Data(#"[{"kind":"hologram"}]"#.utf8)
        try contents.write(to: fileURL)
        let model = makeModel(store: JSONFileCaptureStore(fileURL: fileURL), text: "An idea")

        await model.save()

        #expect(model.text == "An idea")
        #expect(model.saveResult == .failed)
        #expect(try Data(contentsOf: fileURL) == contents)
    }

    @Test func typingClearsTheResult() async {
        let model = makeModel(text: "An idea")
        await model.save()

        model.update(text: "A")

        #expect(model.saveResult == nil)
    }

    @Test func settingTheSameTextKeepsTheResult() async {
        let model = makeModel(text: "An idea")
        await model.save()

        model.update(text: "")

        #expect(model.saveResult == .saved)
    }

    @Test func clearSaveResultForgetsIt() async {
        let model = makeModel(text: "An idea")
        await model.save()

        model.clearSaveResult()

        #expect(model.saveResult == nil)
    }

    @Test func textTypedDuringASaveIsKept() async {
        let store = HookedCaptureStore()
        let model = makeModel(store: store, text: "First")
        await store.setOnAdd { @MainActor in
            model.update(text: "First and more")
        }

        await model.save()

        #expect(model.text == "First and more")
        #expect(await store.base.all().map(\.text) == ["First"])
    }

    @Test func savingWhileASaveRunsDoesNothing() async {
        let store = HookedCaptureStore()
        let model = makeModel(store: store, text: "Once")
        await store.setOnAdd { @MainActor in
            #expect(!model.canSave)
            await model.save()
        }

        await model.save()

        #expect(await store.base.all().count == 1)
    }

    // Typing and saving adds a capture that shows in the list and survives a relaunch.
    @Test func savedCaptureShowsInTheListAfterARelaunch() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = makeModel(store: JSONFileCaptureStore(fileURL: fileURL), text: "Keep me")

        await model.save()
        let store = JSONFileCaptureStore(fileURL: fileURL)
        let queue = SubmissionQueue(store: store, auth: MockAuthService(), client: MockBufferClient())
        let relaunched = CaptureListModel(store: store, submissions: queue)
        await relaunched.load()

        #expect(relaunched.captures.map(\.text) == ["Keep me"])
    }

    @Test func discardingForgetsTheDraftAndTheLastResult() async {
        let model = makeModel(store: ReadOnlyCaptureStore(captures: []), text: "An idea")
        await model.save()
        #expect(model.saveResult == .failed)

        model.discardDraft()

        #expect(model.text.isEmpty)
        #expect(model.saveResult == nil)
    }

    /// What gets a capture on its way to Buffer without waiting for the app to leave the screen.
    @Test func savingTellsWhoeverWantsToKnow() async {
        let saves = SaveCounter()
        let model = CaptureModel(
            store: InMemoryCaptureStore(),
            speech: MockSpeechTranscriber(),
            onSaved: saves.increment
        )
        model.update(text: "An idea")

        await model.save()

        #expect(saves.total == 1)
    }

    @Test func aFailedSaveTellsNobody() async {
        let saves = SaveCounter()
        let model = CaptureModel(
            store: ReadOnlyCaptureStore(captures: []),
            speech: MockSpeechTranscriber(),
            onSaved: saves.increment
        )
        model.update(text: "An idea")

        await model.save()

        #expect(saves.total == 0)
    }
}

@MainActor
private final class SaveCounter {
    private(set) var total = 0

    func increment() {
        total += 1
    }
}
