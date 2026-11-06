import ActivityKit
import AppIntents
import Foundation

/// T1's Live Activity: what's been heard so far, and whether it's still listening.
struct T1DictationAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var text: String
        var status: String
        var startedAt: Date
    }
}

/// T1: one press starts dictation without opening the app. A second press stops it.
///
/// `LiveActivityIntent` puts it in the app's process (on the locked phone, `AudioRecordingIntent` alone ran in the
/// widget's), where `AppleSpeechTranscriber` lives.
struct T1DictateIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "T1 Dictate"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Source")
    var source: String

    init() {}

    init(source: String) {
        self.source = source
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let toggle = SpikeHooks.toggleDictation else {
            await SpikeCapture.save("T1", "error: no dictation in this process (from \(source))")
            return .result()
        }
        await toggle(source)
        return .result()
    }
}

/// The Live Activity's Stop button.
struct T1StopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "T1 Stop"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let stop = SpikeHooks.stopDictation else {
            await SpikeCapture.save("T1", "error: Stop ran with no dictation in this process")
            return .result()
        }
        await stop()
        return .result()
    }
}
