import OSLog
import UIKit
import UserNotifications

/// Throwaway spike, T4: registers the reply action and saves what's typed into it.
///
/// A reply action without `.foreground` launches the app in the background, so this records the app's state too.
final class SpikeAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([SpikeNotificationIDs.makeCategory()])
        return true
    }

    /// Asks for notifications in the app, in case a control in the background can't.
    static func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            Logger().error("Spike T4: can't ask for notifications: \(error)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.categoryIdentifier == SpikeNotificationIDs.category else {
            return
        }
        let action = response.actionIdentifier
        let typed = (response as? UNTextInputNotificationResponse)?.userText
        let appState = await MainActor.run {
            Self.describe(UIApplication.shared.applicationState)
        }
        let outcome: String
        switch action {
        case SpikeNotificationIDs.replyAction:
            outcome = "typed: \(typed ?? "")"
        case UNNotificationDismissActionIdentifier:
            outcome = "error: dismissed without replying"
        case UNNotificationDefaultActionIdentifier:
            outcome = "error: tapped the notification itself, which opens the app"
        default:
            outcome = "error: unknown action \(action)"
        }
        await SpikeCapture.save("T4", "\(outcome) · app was \(appState)")
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private static func describe(_ state: UIApplication.State) -> String {
        switch state {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "in the background"
        @unknown default:
            return "unknown"
        }
    }
}
