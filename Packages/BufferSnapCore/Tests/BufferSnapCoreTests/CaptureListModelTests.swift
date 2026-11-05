import BufferSnapCore
import Testing

@MainActor
struct CaptureListModelTests {
    @Test func startsEmpty() {
        let model = makeModel(store: InMemoryCaptureStore(seed: [.at(1)]))

        #expect(model.captures.isEmpty)
    }

    @Test func loadSortsNewestFirst() async {
        let oldest = Capture.at(1)
        let middle = Capture.at(2, kind: .photo)
        let newest = Capture.at(3, kind: .photo)
        let model = makeModel(store: InMemoryCaptureStore(seed: [middle, newest, oldest]))

        await model.load()

        #expect(model.captures == [newest, middle, oldest])
    }

    @Test func deleteRemovesFromListAndStore() async {
        let older = Capture.at(1)
        let newer = Capture.at(2)
        let store = InMemoryCaptureStore(seed: [older, newer])
        let model = makeModel(store: store)
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
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.delete(capture)

        #expect(model.captures == [capture])
    }

    @Test func resendMakesAFailedCapturePendingAndSendsIt() async {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        await store.setStatus(.failed, ids: [capture.id])
        let buffer = MockBufferClient()
        let model = makeModel(store: store, buffer: buffer)
        await model.load()
        #expect(model.captures.map(\.status) == [.failed])

        await model.resend(capture)

        while await buffer.createdIdeas.isEmpty {
            await Task.yield()
        }
        #expect(await buffer.createdIdeas == ["An idea"])
    }

    /// The row mustn't still say "Failed" with its button after the tap.
    @Test func resendShowsTheNewStatusAtOnce() async {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        await store.setStatus(.failed, ids: [capture.id])
        let model = makeModel(store: store)
        await model.load()

        await model.resend(capture)

        #expect(model.captures.map(\.status) != [.failed])
    }

    @Test func aFailedResendLeavesItFailed() async {
        let capture = Capture(kind: .text, status: .failed, text: "An idea")
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.resend(capture)

        #expect(model.captures == [capture])
    }

    /// A send finishing while the list is open shows without leaving and coming back.
    @Test func theListFollowsSendsWhileItsOpen() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = MockAuthService(hasSavedSession: true)
        let queue = SubmissionQueue(store: store, auth: auth, client: MockBufferClient())
        let model = CaptureListModel(store: store, submissions: queue)

        let following = Task {
            await model.loadAndFollowChanges()
        }
        while model.captures.isEmpty {
            await Task.yield()
        }
        await queue.run()
        while model.captures.map(\.status) != [.submitted] {
            await Task.yield()
        }
        following.cancel()
    }

    private func makeModel(
        store: any CaptureStore,
        buffer: MockBufferClient = MockBufferClient()
    ) -> CaptureListModel {
        let auth = MockAuthService(hasSavedSession: true)
        return CaptureListModel(
            store: store,
            submissions: SubmissionQueue(store: store, auth: auth, client: buffer)
        )
    }
}
