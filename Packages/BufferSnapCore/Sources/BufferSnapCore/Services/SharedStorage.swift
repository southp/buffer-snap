import Foundation

/// What the app and the widget must agree on to share captures. Both are separate processes, so these names are the
/// contract between them.
public enum SharedStorage {
    /// Thrown when the system has no container for `groupID`, which means the target lacks the App Groups entitlement.
    public struct ContainerUnavailable: Error {}

    /// The App Group both targets' entitlements list.
    public static let groupID = "group.me.southp.buffersnap"

    /// The widget's kind, which the app needs to reload its timelines. Core can't import WidgetKit, so this is a name.
    public static let widgetKind = "SnapperWidget"

    /// The JSON file `JSONFileCaptureStore` keeps the shared captures in.
    public static func capturesFileURL() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw ContainerUnavailable()
        }
        return container.appendingPathComponent("captures.json")
    }
}
