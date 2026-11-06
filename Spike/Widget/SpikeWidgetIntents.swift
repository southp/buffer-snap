import AppIntents
import Foundation

// Throwaway spike. Only the widget compiles these, so they run in the widget's process.

/// T3: asks for the idea in a text box, from the widget's process.
struct T3TypeInWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "T3 Type (widget)"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Idea")
    var idea: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$idea)")
    }

    func perform() async throws -> some IntentResult {
        do {
            let value: String
            if let idea {
                value = idea
            } else {
                value = try await $idea.requestValue("What's the idea?")
            }
            await SpikeCapture.save("T3", "typed: \(value)")
        } catch {
            await SpikeCapture.save("T3", "error: \(error)")
        }
        return .result()
    }
}

/// T5: a required parameter, which the system must ask for before `perform()` can run.
struct T5RequiredIntent: AppIntent {
    static let title: LocalizedStringResource = "T5 Required idea"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Idea", requestValueDialog: "What's the idea?")
    var idea: String

    func perform() async throws -> some IntentResult {
        await SpikeCapture.save("T5", "typed: \(idea)")
        return .result()
    }
}
