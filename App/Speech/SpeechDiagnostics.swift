import Foundation
import Observation
import SwiftUI

/// What `AppleSpeechTranscriber` tells the on-screen diagnostics. Nothing in Release builds.
///
/// Settings, counts and error codes, never the words, so the strip is safe to read out. Remove this file and its call
/// sites once the device test in #42 is done with it.
enum SpeechDiagnosticsLog {
    static func options() async -> AppleSpeechTranscriber.Options {
        #if DEBUG
            await SpeechDiagnostics.shared.options
        #else
            AppleSpeechTranscriber.Options()
        #endif
    }

    static func started(language: String, recognizerLocale: String, supportsOnDevice: Bool, requiresOnDevice: Bool) {
        #if DEBUG
            Task { @MainActor in
                SpeechDiagnostics.shared.started(
                    language: language,
                    recognizerLocale: recognizerLocale,
                    supportsOnDevice: supportsOnDevice,
                    requiresOnDevice: requiresOnDevice
                )
            }
        #endif
    }

    static func couldNotStart(language: String, error: (any Error)?) {
        #if DEBUG
            let reason = error.map(describe) ?? "recognizer unavailable"
            Task { @MainActor in
                SpeechDiagnostics.shared.couldNotStart(language: language, reason: reason)
            }
        #endif
    }

    static func heard(characterCount: Int) {
        #if DEBUG
            Task { @MainActor in
                SpeechDiagnostics.shared.heard(characterCount: characterCount)
            }
        #endif
    }

    static func released() {
        #if DEBUG
            Task { @MainActor in
                SpeechDiagnostics.shared.released()
            }
        #endif
    }

    static func ended(_ ending: String) {
        #if DEBUG
            Task { @MainActor in
                SpeechDiagnostics.shared.ended(ending)
            }
        #endif
    }

    static func ended(error: any Error) {
        #if DEBUG
            ended(describe(error))
        #endif
    }

    #if DEBUG
        /// The domain and code only: an error's description could in principle quote what was said.
        private static func describe(_ error: any Error) -> String {
            let error = error as NSError
            return "error \(error.domain) \(error.code)"
        }
    #endif
}

#if DEBUG
    /// What the device test of dictation needs to know, shown on the capture screen.
    @Observable
    @MainActor
    final class SpeechDiagnostics {
        static let shared = SpeechDiagnostics()

        /// A language to test instead of the iPhone's. Empty follows the iPhone.
        var language = ""
        var requiresOnDevice = false
        private(set) var setup = "Hold the mic to fill this in"
        private(set) var lastHold = ""

        private var pressedAt = Date.now
        private var releasedAt: Date?
        private var endedAt: Date?
        private var longest = 0
        private var previous = 0
        private var shrinks = 0
        private var ending: String?

        var options: AppleSpeechTranscriber.Options {
            AppleSpeechTranscriber.Options(
                language: language.isEmpty ? nil : language,
                requiresOnDevice: requiresOnDevice
            )
        }

        func started(language: String, recognizerLocale: String, supportsOnDevice: Bool, requiresOnDevice: Bool) {
            pressedAt = .now
            releasedAt = nil
            endedAt = nil
            longest = 0
            previous = 0
            shrinks = 0
            ending = nil
            let mode = requiresOnDevice ? "on-device only" : "iOS chooses"
            setup = "asked \(language), got \(recognizerLocale). on-device: \(supportsOnDevice ? "yes" : "no"), \(mode)"
            updateLastHold()
        }

        func couldNotStart(language: String, reason: String) {
            setup = "asked \(language), can't start: \(reason)"
            lastHold = ""
        }

        func heard(characterCount: Int) {
            // Falling by half means the recognizer dropped earlier words, as some iOS 18 versions do after a pause.
            if characterCount < previous / 2 {
                shrinks += 1
            }
            previous = characterCount
            longest = max(longest, characterCount)
            updateLastHold()
        }

        func released() {
            releasedAt = .now
            updateLastHold()
        }

        func ended(_ ending: String) {
            guard self.ending == nil else {
                return
            }
            self.ending = ending
            endedAt = .now
            updateLastHold()
        }

        private func updateLastHold() {
            var parts = [
                String(format: "held %.1fs", (releasedAt ?? endedAt ?? .now).timeIntervalSince(pressedAt)),
                "\(longest) chars",
                "dropped \(shrinks)x",
            ]
            if let releasedAt, let endedAt {
                parts.append(String(format: "last words +%.1fs", endedAt.timeIntervalSince(releasedAt)))
            }
            parts.append(ending ?? (releasedAt == nil ? "listening" : "finishing"))
            lastHold = parts.joined(separator: ", ")
        }
    }

    /// The strip at the bottom of the capture screen, with the two settings the device test compares.
    struct SpeechDiagnosticsView: View {
        @Bindable private var diagnostics = SpeechDiagnostics.shared

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Picker(selection: $diagnostics.language) {
                        Text(verbatim: "iPhone").tag("")
                        Text(verbatim: "zh-TW").tag("zh-TW")
                        Text(verbatim: "en-US").tag("en-US")
                    } label: {
                        Text(verbatim: "Language")
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $diagnostics.requiresOnDevice) {
                        Text(verbatim: "On-device")
                    }
                    .fixedSize()
                }
                Text(verbatim: diagnostics.setup)
                Text(verbatim: diagnostics.lastHold)
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }
#endif
