import BufferSnapCore
import Foundation
import Testing

struct BatchWindowSettingTests {
    private let suiteName = "BatchWindowSettingTests-\(UUID().uuidString)"

    @Test func itStartsAtFiveMinutes() {
        #expect(UserDefaultsBatchWindowSetting(suiteName: suiteName).window == 300)
        #expect(InMemoryBatchWindowSetting().window == 300)
    }

    /// Off is a choice that was made, not a setting that was never touched.
    @Test func offIsRememberedAsOff() {
        let setting = UserDefaultsBatchWindowSetting(suiteName: suiteName)

        setting.setWindow(BatchWindow.off)

        #expect(setting.window == 0)
    }

    @Test func aChoiceLastsAcrossInstances() {
        UserDefaultsBatchWindowSetting(suiteName: suiteName).setWindow(600)

        #expect(UserDefaultsBatchWindowSetting(suiteName: suiteName).window == 600)
    }

    /// A launch argument arrives as a string. It's how a simulator run gets a short window.
    @Test func aWindowFromALaunchArgumentCounts() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set("20", forKey: "batchWindow")

        #expect(UserDefaultsBatchWindowSetting(suiteName: suiteName).window == 20)
    }

    @Test func aNegativeWindowCountsAsOff() {
        let setting = UserDefaultsBatchWindowSetting(suiteName: suiteName)

        setting.setWindow(-5)

        #expect(setting.window == 0)
    }

    @Test func theOptionsIncludeOffAndTheDefault() {
        #expect(BatchWindow.options.contains(BatchWindow.off))
        #expect(BatchWindow.options.contains(BatchWindow.standard))
        #expect(BatchWindow.standard == 300)
    }
}

@MainActor
struct BatchingSettingsModelTests {
    @Test func itShowsTheCurrentSetting() {
        let store = InMemoryCaptureStore()
        let queue = SubmissionQueue(
            store: store,
            auth: MockAuthService(hasSavedSession: true),
            client: MockBufferClient()
        )

        let model = BatchingSettingsModel(setting: InMemoryBatchWindowSetting(window: 120), submissions: queue)

        #expect(model.window == 120)
    }

    /// Turning it off with a batch open must send it, without waiting for anything else to happen.
    @Test func choosingMakesTheQueuePlanAgainWithTheNewWindow() async {
        let setting = InMemoryBatchWindowSetting()
        let store = InMemoryCaptureStore(seed: [Capture(kind: .text, text: "An idea")])
        let buffer = MockBufferClient()
        let queue = SubmissionQueue(
            store: store,
            auth: MockAuthService(hasSavedSession: true),
            client: buffer,
            planner: SubmissionPlanner { setting.window }
        )
        await queue.run()
        #expect(await buffer.createdIdeas.isEmpty)
        let model = BatchingSettingsModel(setting: setting, submissions: queue)

        await model.choose(BatchWindow.off)

        #expect(model.window == 0)
        #expect(setting.window == 0)
        while await buffer.createdIdeas.isEmpty {
            await Task.yield()
        }
        #expect(await buffer.createdIdeas == ["An idea"])
    }
}

/// What changing the setting does to what's waiting: `docs/decisions/45-changing-the-window.md`.
struct ChangingTheWindowTests {
    private let fixture = QueueFixture()
    private var server: FakeIdeasServer {
        fixture.server
    }
    private var clock: ManualSubmissionClock {
        fixture.clock
    }

    private func makeQueue(store: any CaptureStore, setting: InMemoryBatchWindowSetting) -> SubmissionQueue {
        fixture.makeQueue(store: store, planner: SubmissionPlanner { setting.window })
    }

    @Test func aLongerWindowPushesTheOpenBatchBack() async {
        let setting = InMemoryBatchWindowSetting(window: 300)
        let store = InMemoryCaptureStore(seed: [fixture.capture("An idea", ago: 100)])
        let queue = makeQueue(store: store, setting: setting)
        await queue.run()
        #expect(await clock.waitForSleep(number: 1) == 200)

        setting.setWindow(600)
        await queue.replan()

        #expect(await clock.waitForSleep(number: 2) == 500)
        #expect(await server.ideaRequests == 0)
    }

    /// Its time has already passed under the new window, and each capture counts from its own timestamp.
    @Test func aShorterWindowSendsWhatsNowDue() async {
        let setting = InMemoryBatchWindowSetting(window: 300)
        let store = InMemoryCaptureStore(seed: [fixture.capture("An idea", ago: 100)])
        let queue = makeQueue(store: store, setting: setting)
        await queue.run()

        setting.setWindow(60)
        await queue.replan()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["An idea"])
    }

    @Test func aShorterWindowSplitsCapturesThatAreNowTooFarApart() async {
        let setting = InMemoryBatchWindowSetting(window: 300)
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 200), fixture.capture("Second", ago: 100),
        ])
        let queue = makeQueue(store: store, setting: setting)
        await queue.run()

        setting.setWindow(60)
        await queue.replan()
        await fixture.waitForIdeas(2)

        #expect(await server.ideaTexts == ["First", "Second"])
    }

    /// Captures further apart than the old window, and neither gone yet, as when the app was away.
    @Test func aLongerWindowJoinsCapturesThatAreNowCloseEnough() async {
        let setting = InMemoryBatchWindowSetting(window: 60)
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 100), fixture.capture("Second")])
        setting.setWindow(300)
        let queue = makeQueue(store: store, setting: setting)

        await queue.run()
        #expect(await clock.waitForSleep(number: 1) == 300)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First\n\nSecond"])
    }

    @Test func turningItOffSendsEachOpenCaptureByItselfAtOnce() async {
        let setting = InMemoryBatchWindowSetting(window: 300)
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 2), fixture.capture("Second")])
        let queue = makeQueue(store: store, setting: setting)
        await queue.run()

        setting.setWindow(BatchWindow.off)
        await queue.replan()
        await fixture.waitForIdeas(2)

        #expect(await server.ideaTexts == ["First", "Second"])
    }

    @Test func withItOffACaptureGoesAsSoonAsItsSaved() async throws {
        let store = InMemoryCaptureStore()
        let queue = makeQueue(store: store, setting: InMemoryBatchWindowSetting(window: BatchWindow.off))

        try await store.add(fixture.capture("An idea"))
        await queue.run()

        #expect(await server.ideaTexts == ["An idea"])
    }

    /// It may already have reached Buffer, so it must not change.
    @Test func aClosedBatchStaysTheSameWhenTheWindowChanges() async {
        let setting = InMemoryBatchWindowSetting(window: 300)
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 500), fixture.capture("Second", ago: 400),
        ])
        let queue = makeQueue(store: store, setting: setting)
        await server.failIdeas(.offline)
        await queue.run()

        setting.setWindow(BatchWindow.off)
        await queue.run()

        #expect(await server.ideaTexts == ["First\n\nSecond"])
    }

    /// A list that's open behind the setting has to show the new grouping when you come back.
    @MainActor
    @Test func theListFollowsTheNewWindow() async {
        let setting = InMemoryBatchWindowSetting(window: 300)
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 200), fixture.capture("Second", ago: 100),
        ])
        let queue = makeQueue(store: store, setting: setting)
        let model = CaptureListModel(store: store, submissions: queue)
        let following = Task {
            await model.loadAndFollowChanges()
        }
        while model.batches.count != 1 {
            await Task.yield()
        }

        setting.setWindow(60)
        await queue.replan()

        while model.batches.count != 2 {
            await Task.yield()
        }
        following.cancel()
    }
}
