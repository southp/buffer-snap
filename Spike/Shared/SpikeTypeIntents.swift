import AppIntents
import Foundation
import UserNotifications

/// T2: asks for the idea in a text box. `LiveActivityIntent` only to run in the app's process; it starts no activity.
struct T2TypeInAppIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "T2 Type (app)"
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
            await SpikeCapture.save("T2", "typed: \(value)")
        } catch {
            await SpikeCapture.save("T2", "error: \(error)")
        }
        return .result()
    }
}

/// T4: posts a notification with a reply box. The app saves the reply (`SpikeNotifications`). `LiveActivityIntent`
/// only to run in the app's process, which registered the reply's category.
struct T4NotifyIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "T4 Type via notification"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                await SpikeCapture.save("T4", "error: asking for permission: \(error)")
                return .result()
            }
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            await SpikeCapture.save("T4", "error: notifications not allowed (status \(status.rawValue))")
            return .result()
        }
        let content = UNMutableNotificationContent()
        content.title = "What's the idea?"
        content.body = "Press and hold, or pull down, to reply."
        content.categoryIdentifier = SpikeNotificationIDs.category
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
            await SpikeCapture.save("T4", "error: posting: \(error)")
        }
        return .result()
    }
}

/// The names T4's notification and the app's handler agree on.
enum SpikeNotificationIDs {
    static let category = "spike.t4.reply"
    static let replyAction = "spike.t4.reply.action"

    /// Registered by the app at launch. The reply doesn't open the app: it's launched in the background instead.
    static func makeCategory() -> UNNotificationCategory {
        let reply = UNTextInputNotificationAction(
            identifier: replyAction,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Save",
            textInputPlaceholder: "What's the idea?"
        )
        return UNNotificationCategory(
            identifier: category,
            actions: [reply],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }
}
