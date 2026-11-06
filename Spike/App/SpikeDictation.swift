import ActivityKit
import BufferSnapCore
import Foundation
import UIKit

/// Throwaway spike, T1: dictation started by an intent, in the app's process, without the app on screen.
///
/// It runs PR #53's `AppleSpeechTranscriber`, the real in-app path, with only the audio session changed to mix with
/// others. It ends on Stop, a second press, 3 seconds without new words once something's been heard, or 60 seconds.
@MainActor
final class SpikeDictation {
    static let shared = SpikeDictation()

    private static let silence: TimeInterval = 3
    private static let limit: TimeInterval = 60

    private let transcriber = AppleSpeechTranscriber(mixesWithOthers: true)
    private var runID: UUID?
    private var source = ""
    private var heard = ""
    private var startedAt = Date.now
    private var lastChange = Date.now
    private var lastActivityUpdate = Date.distantPast
    private var endReason: String?
    /// Not the `Activity` itself: it isn't `Sendable`.
    private var activityID: String?
    private var activityNote = ""
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// Lets T1's intents reach this, which only the app compiles.
    static func install() {
        SpikeHooks.toggleDictation = { source in
            await shared.toggle(source: source)
        }
        SpikeHooks.stopDictation = {
            await shared.stop(reason: "Stop button")
        }
    }

    /// Asks for the microphone and speech recognition in the app, since an intent in the background can't.
    func requestPermission() async {
        _ = await transcriber.requestPermission()
    }

    func toggle(source: String) async {
        if runID != nil {
            await stop(reason: "pressed again")
            return
        }
        await start(source: source)
    }

    private func start(source: String) async {
        let permission = await transcriber.permission()
        guard permission == .granted else {
            await SpikeCapture.save("T1", "error: permission is \(permission), so open the app once (from \(source))")
            return
        }
        let id = UUID()
        runID = id
        self.source = source
        heard = ""
        startedAt = .now
        lastChange = .now
        endReason = nil
        startActivity()

        let stream: AsyncThrowingStream<String, any Error>
        do {
            stream = try await transcriber.start()
        } catch {
            runID = nil
            await endActivity(status: "Couldn't listen")
            await SpikeCapture.save("T1", "error: starting: \(error) (from \(source))\(activityNote)")
            return
        }
        Task {
            await self.listen(to: stream, id: id)
        }
        Task {
            await self.watch(id: id)
        }
    }

    func stop(reason: String) async {
        guard let id = runID, endReason == nil else {
            return
        }
        endReason = reason
        beginBackgroundTask()
        await updateActivity(status: "Finishing…", force: true)
        await transcriber.finish()
        // The recognizer may never send its last words; give up on them after 5 seconds.
        try? await Task.sleep(for: .seconds(5))
        if runID == id {
            await transcriber.cancel()
        }
    }

    private func listen(to stream: AsyncThrowingStream<String, any Error>, id: UUID) async {
        var failure: (any Error)?
        do {
            for try await words in stream {
                guard runID == id else {
                    break
                }
                if words != heard {
                    heard = words
                    lastChange = .now
                    await updateActivity(status: "Listening", force: false)
                }
            }
        } catch {
            failure = error
        }
        await finished(id: id, failure: failure)
    }

    /// Ends the run on silence after speech, or at the time limit.
    private func watch(id: UUID) async {
        while runID == id, endReason == nil {
            try? await Task.sleep(for: .milliseconds(250))
            guard runID == id, endReason == nil else {
                return
            }
            if Date.now.timeIntervalSince(startedAt) >= Self.limit {
                await stop(reason: "60 s limit")
                return
            }
            if !heard.isEmpty, Date.now.timeIntervalSince(lastChange) >= Self.silence {
                await stop(reason: "3 s of silence")
                return
            }
        }
    }

    private func finished(id: UUID, failure: (any Error)?) async {
        guard runID == id else {
            return
        }
        runID = nil
        let seconds = Int(Date.now.timeIntervalSince(startedAt))
        let ending = endReason ?? failure.map { "\($0)" } ?? "the recognizer, by itself"
        let details = " · ended by \(ending) after \(seconds) s, from \(source)\(activityNote)"
        if heard.isEmpty {
            await endActivity(status: "Nothing heard")
            await SpikeCapture.save("T1", "error: nothing heard\(details)")
        } else {
            await endActivity(status: "Saved")
            await SpikeCapture.save("T1", "dictated: \(heard)\(details)")
        }
        endBackgroundTask()
    }

    private func startActivity() {
        lastActivityUpdate = .distantPast
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityID = nil
            activityNote = " · Live Activities are off"
            return
        }
        do {
            activityID = try Activity.request(
                attributes: T1DictationAttributes(),
                content: ActivityContent(state: state(status: "Listening"), staleDate: nil)
            ).id
            activityNote = ""
        } catch {
            activityID = nil
            activityNote = " · no Live Activity: \(error)"
        }
    }

    /// Shows the words so far, at most twice a second unless `force`.
    private func updateActivity(status: String, force: Bool) async {
        guard let id = activityID, force || Date.now.timeIntervalSince(lastActivityUpdate) >= 0.5 else {
            return
        }
        lastActivityUpdate = .now
        await Self.update(id: id, to: state(status: status))
    }

    private func endActivity(status: String) async {
        guard let id = activityID else {
            return
        }
        activityID = nil
        await Self.end(id: id, with: state(status: status))
    }

    // `Activity` isn't `Sendable`, so it's only ever touched outside the main actor, looked up afresh each time.

    private nonisolated static func update(id: String, to state: T1DictationAttributes.ContentState) async {
        for activity in Activity<T1DictationAttributes>.activities where activity.id == id {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private nonisolated static func end(id: String, with state: T1DictationAttributes.ContentState) async {
        for activity in Activity<T1DictationAttributes>.activities where activity.id == id {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 5))
        }
    }

    private func state(status: String) -> T1DictationAttributes.ContentState {
        T1DictationAttributes.ContentState(text: heard, status: status, startedAt: startedAt)
    }

    /// Once the audio stops, the background audio mode no longer keeps the app running for the last words.
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else {
            return
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "T1 dictation") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
