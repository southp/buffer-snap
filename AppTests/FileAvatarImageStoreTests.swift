import BufferSnapCore
import Foundation
import Testing

/// Where the picture lands on the iPhone. Core's tests cover the rest on macOS, which has no app container. Neither
/// macOS nor the simulator reports a file's protection, so Core's tests check the options it's written with.
struct FileAvatarImageStoreTests {
    /// In the app's own Application Support, never the App Group the widget shares.
    @Test func thePictureIsInTheAppsOwnContainer() throws {
        let directory = FileAvatarImageStore().directory.standardizedFileURL.path(percentEncoded: false)
        let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStorage.groupID)

        #expect(directory.contains("/Library/Application Support/"))
        #expect(directory.hasPrefix(URL.applicationSupportDirectory.standardizedFileURL.path(percentEncoded: false)))
        if let group {
            #expect(!directory.hasPrefix(group.standardizedFileURL.path(percentEncoded: false)))
        }
    }
}
