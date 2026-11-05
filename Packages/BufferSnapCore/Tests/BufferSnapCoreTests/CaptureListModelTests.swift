import BufferSnapCore
import Testing

@MainActor
struct CaptureListModelTests {
    @Test func startsEmpty() {
        let model = CaptureListModel(store: InMemoryCaptureStore(seed: [.at(1)]))

        #expect(model.captures.isEmpty)
    }

    @Test func loadSortsNewestFirst() async {
        let oldest = Capture.at(1)
        let middle = Capture.at(2, kind: .photo)
        let newest = Capture.at(3, kind: .photo)
        let model = CaptureListModel(store: InMemoryCaptureStore(seed: [middle, newest, oldest]))

        await model.load()

        #expect(model.captures == [newest, middle, oldest])
    }

    @Test func deleteRemovesFromListAndStore() async {
        let older = Capture.at(1)
        let newer = Capture.at(2)
        let store = InMemoryCaptureStore(seed: [older, newer])
        let model = CaptureListModel(store: store)
        await model.load()

        await model.delete(older)

        #expect(model.captures == [newer])
        #expect(await store.all() == [newer])

        // The store is the source of truth: a reload must not bring the capture back.
        await model.load()
        #expect(model.captures == [newer])
    }

    @Test func failedDeleteKeepsCapture() async {
        let capture = Capture.at(1)
        let model = CaptureListModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.delete(capture)

        #expect(model.captures == [capture])
    }
}
