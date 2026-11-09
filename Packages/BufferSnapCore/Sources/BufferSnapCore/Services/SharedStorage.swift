import Foundation

/// Where the app keeps its captures: a file in the App Group container.
public enum SharedStorage {
    /// Thrown when the system has no container for `groupID`, which means the target lacks the App Groups entitlement.
    public struct ContainerUnavailable: Error {}

    /// The App Group both targets' entitlements list.
    public static let groupID = "group.me.southp.buffersnap"

    /// The JSON file `JSONFileCaptureStore` keeps the shared captures in.
    public static func capturesFileURL() throws -> URL {
        capturesFileURL(inContainer: try containerURL())
    }

    /// The captures file in `container`.
    ///
    /// Not `captures.json`: that's where builds before #40 kept captures, and all they could write was mock captures,
    /// some with kinds that no longer exist. Bump this name to start over the same way.
    public static func capturesFileURL(inContainer container: URL) -> URL {
        container.appendingPathComponent("captures-v2.json")
    }

    /// Deletes the file builds before #40 kept their mock captures in.
    public static func removeLegacyCaptures() throws {
        try removeLegacyCaptures(inContainer: containerURL())
    }

    /// Deletes the file builds before #40 kept their mock captures in from `container`. Does nothing if it's gone.
    public static func removeLegacyCaptures(inContainer container: URL) throws {
        let legacyFileURL = container.appendingPathComponent("captures.json")
        if FileManager.default.fileExists(atPath: legacyFileURL.path) {
            try FileManager.default.removeItem(at: legacyFileURL)
        }
    }

    private static func containerURL() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw ContainerUnavailable()
        }
        return container
    }
}
