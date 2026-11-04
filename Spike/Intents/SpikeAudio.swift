import AVFoundation
import ActivityKit
import AppIntents

/// Throwaway (#10): recording from a locked phone needs a Live Activity started at once.
struct SpikeAudioAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }
}

@MainActor
enum SpikeRecorder {
    private static var recorder: AVAudioRecorder?
    private static var startedAt: Date?

    static func start() throws -> String {
        guard let directory = SpikeLog.directory else {
            return "no App Group"
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ]
        let url = directory.appendingPathComponent("spike-audio.m4a")
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        let started = recorder.record()
        self.recorder = recorder
        startedAt = .now
        return "record()=\(started) isRecording=\(recorder.isRecording)"
    }

    static func stop() -> String {
        guard let recorder else {
            return "no recorder in this process"
        }
        let seconds = recorder.currentTime
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
        let wall = startedAt.map { Date.now.timeIntervalSince($0) } ?? -1
        return "recorded=\(Int(seconds))s wall=\(Int(wall))s bytes=\(size)"
    }
}

struct SpikeAudioStartIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Spike record"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        SpikeLog.write("audio-start", surface: "control", detail: "activities=\(enabled)")
        do {
            let state = SpikeAudioAttributes.ContentState(startedAt: .now)
            _ = try Activity.request(
                attributes: SpikeAudioAttributes(),
                content: ActivityContent(state: state, staleDate: nil)
            )
            SpikeLog.write("audio-activity-ok", surface: "control")
        } catch {
            SpikeLog.write("audio-activity-error", surface: "control", detail: "\(error)")
        }
        do {
            SpikeLog.write("audio-recording", surface: "control", detail: try SpikeRecorder.start())
        } catch {
            SpikeLog.write("audio-record-error", surface: "control", detail: "\(error)")
        }
        return .result()
    }
}

struct SpikeAudioStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Spike stop recording"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult {
        SpikeLog.write("audio-stop", surface: "liveactivity", detail: SpikeRecorder.stop())
        for activity in Activity<SpikeAudioAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
