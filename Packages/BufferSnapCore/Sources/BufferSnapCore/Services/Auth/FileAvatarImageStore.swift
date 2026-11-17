import CryptoKit
import Foundation
import OSLog

/// Keeps the signed-in account's profile picture as one file in the app's own container: Application Support, never the
/// App Group, which the widget would share, and never `URLCache`, which nothing would clear at sign-out
/// (`docs/decisions/108-avatar-from-buffers-s3.md`).
///
/// The file is readable after the first unlock (`completeUntilFirstUserAuthentication`), like the account's Keychain
/// item, and its folder is out of backups, as the Keychain item is. It's named after a SHA-256 of the URL it came from,
/// so the URL, which holds the account's ID, is never written down here.
public struct FileAvatarImageStore: AvatarImageStore {
    /// How the picture is written: whole or not at all, and readable after the first unlock.
    public static let writingOptions: Data.WritingOptions = [
        .atomic,
        .completeFileProtectionUntilFirstUserAuthentication,
    ]

    /// The folder the picture is in. Nothing else goes in it, as `clear()` removes it whole.
    public let directory: URL

    public init(
        directory: URL = .applicationSupportDirectory.appending(path: "AccountAvatar", directoryHint: .isDirectory)
    ) {
        self.directory = directory
    }

    public func load() -> Data? {
        guard let file = savedFiles().first else {
            return nil
        }
        do {
            return try Data(contentsOf: file)
        } catch {
            // The next download replaces it. Until then, initials.
            Logger.auth.error("Can't read the saved picture: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    public func holds(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: file(for: url).path(percentEncoded: false))
    }

    public func save(_ image: Data, from url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var folder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        let file = file(for: url)
        try image.write(to: file, options: Self.writingOptions)
        for other in savedFiles() where other.lastPathComponent != file.lastPathComponent {
            try FileManager.default.removeItem(at: other)
        }
    }

    public func clear() throws {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }

    private func file(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: name, directoryHint: .notDirectory)
    }

    /// Normally one. A save that stopped before removing the old one leaves two, both of this account.
    private func savedFiles() -> [URL] {
        let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return files ?? []
    }
}
