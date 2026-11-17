import BufferSnapCore
import Foundation
import Testing

/// The saved picture, in a folder of its own. On macOS here; the file protection is checked on the simulator, in the
/// app's tests.
struct FileAvatarImageStoreTests {
    private let store = FileAvatarImageStore(
        directory: FileManager.default.temporaryDirectory.appending(path: "avatar-tests-\(UUID().uuidString)")
    )

    @Test func startsEmpty() {
        #expect(store.load() == nil)
        #expect(!store.holds(AvatarFixtures.url("ada")))
    }

    @Test func aSavedPictureComesBackWithWhereItCameFrom() throws {
        defer { try? store.clear() }

        try store.save(AvatarFixtures.png, from: AvatarFixtures.url("ada"))

        #expect(store.load() == AvatarFixtures.png)
        #expect(store.holds(AvatarFixtures.url("ada")))
        #expect(!store.holds(AvatarFixtures.url("grace")))
    }

    /// One picture at a time: the old one goes.
    @Test func savingAnotherReplacesIt() throws {
        defer { try? store.clear() }

        try store.save(AvatarFixtures.png, from: AvatarFixtures.url("ada"))
        try store.save(AvatarFixtures.otherPNG, from: AvatarFixtures.url("ada-new"))

        #expect(store.load() == AvatarFixtures.otherPNG)
        #expect(!store.holds(AvatarFixtures.url("ada")))
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path()).count == 1)
    }

    @Test func clearingRemovesItAndCanRepeat() throws {
        try store.save(AvatarFixtures.png, from: AvatarFixtures.url("ada"))

        try store.clear()
        try store.clear()

        #expect(store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.directory.path()))
    }

    /// The URL holds the account's ID, so it isn't written down: the file is named after its hash.
    @Test func theURLIsntWrittenDown() throws {
        defer { try? store.clear() }
        try store.save(AvatarFixtures.png, from: AvatarFixtures.url("ada"))

        let names = try FileManager.default.contentsOfDirectory(atPath: store.directory.path())

        #expect(names.count == 1)
        #expect(names.allSatisfy { $0.count == 64 && !$0.contains("ada") })
    }

    /// Like the account's Keychain item, it never goes into a backup.
    @Test func theFolderIsOutOfBackups() throws {
        defer { try? store.clear() }
        try store.save(AvatarFixtures.png, from: AvatarFixtures.url("ada"))

        let values = try store.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])

        #expect(values.isExcludedFromBackup == true)
    }
}
