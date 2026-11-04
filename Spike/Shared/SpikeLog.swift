import Foundation

/// Throwaway (#10): an append-only log in the App Group, so each run on a locked phone records itself.
enum SpikeLog {
    static let groupID = "group.me.southp.buffersnap"

    static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static var fileURL: URL? {
        directory?.appendingPathComponent("spike-log.txt")
    }

    private static var probeURL: URL? {
        directory?.appendingPathComponent("spike-probe")
    }

    /// Writes a file only readable while the phone is unlocked. Only call this while unlocked.
    static func writeProbe() {
        guard let probeURL else {
            return
        }
        try? Data("probe".utf8).write(to: probeURL, options: [.atomic, .completeFileProtection])
    }

    /// The objective lock state: iOS drops the key to a `.complete` file about 10 seconds after locking.
    static func lockState() -> String {
        guard let probeURL else {
            return "NO-GROUP"
        }
        guard FileManager.default.fileExists(atPath: probeURL.path) else {
            return "NO-PROBE"
        }
        do {
            _ = try Data(contentsOf: probeURL)
            return "unlocked"
        } catch {
            return "LOCKED"
        }
    }

    static func line(_ event: String, surface: String, detail: String = "") -> String {
        let time = Date.now.formatted(.iso8601.time(includingFractionalSeconds: false))
        return "\(time) | \(event) | \(surface) | \(lockState()) | \(ProcessInfo.processInfo.processName) | \(detail)\n"
    }

    static func write(_ event: String, surface: String, detail: String = "") {
        append(line(event, surface: surface, detail: detail))
    }

    static func append(_ text: String) {
        guard let fileURL else {
            return
        }
        let manager = FileManager.default
        if !manager.fileExists(atPath: fileURL.path) {
            let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.none]
            manager.createFile(atPath: fileURL.path, contents: nil, attributes: attributes)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            return
        }
        defer {
            try? handle.close()
        }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(text.utf8))
    }

    static func read() -> String {
        guard let fileURL, let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ""
        }
        return text
    }

    static func clear() {
        guard let fileURL else {
            return
        }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
