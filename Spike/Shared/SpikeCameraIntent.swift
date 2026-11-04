import AppIntents

/// Throwaway (#10): opens the lock screen camera extension. Must be compiled into the app, widget and extension.
struct SpikeCameraContext: Codable, Sendable {}

struct SpikeCameraIntent: CameraCaptureIntent {
    typealias AppContext = SpikeCameraContext

    static let title: LocalizedStringResource = "Spike camera"

    func perform() async throws -> some IntentResult {
        SpikeLog.write("camera-intent", surface: "control")
        return .result()
    }
}
