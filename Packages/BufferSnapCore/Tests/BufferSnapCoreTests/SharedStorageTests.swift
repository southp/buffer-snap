import BufferSnapCore
import Foundation
import Testing

/// Installing over a build from before #40: its `captures.json` holds only mock captures, some of kinds that are gone.
struct SharedStorageTests {
    /// An App Group container as such a build left it.
    private func containerWithLegacyCaptures() throws -> URL {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        try Data(Self.legacyCaptures.utf8).write(to: legacyFileURL(in: container))
        return container
    }

    private func legacyFileURL(in container: URL) -> URL {
        container.appendingPathComponent("captures.json")
    }

    /// What those builds wrote: samples and widget mocks, in kinds that still exist and kinds that don't.
    private static let legacyCaptures = """
        [
          {"id":"00000000-0000-0000-0000-000000000001","kind":"text","createdAt":784000000,"status":"pending",
           "text":"Idea for Friday's post"},
          {"id":"00000000-0000-0000-0000-000000000003","kind":"audio","createdAt":784000000,"status":"failed"},
          {"id":"00000000-0000-0000-0000-000000000005","kind":"video","createdAt":784000000,"status":"pending",
           "text":"Launch teaser"},
          {"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","kind":"text","createdAt":784000000,"status":"pending",
           "text":"Mock text capture"}
        ]
        """

    @Test func storeStartsEmptyOverALegacyFile() async throws {
        let container = try containerWithLegacyCaptures()
        let store = JSONFileCaptureStore(fileURL: SharedStorage.capturesFileURL(inContainer: container))

        #expect(try await store.all().isEmpty)
    }

    @Test func storeSavesAndReloadsOverALegacyFile() async throws {
        let container = try containerWithLegacyCaptures()
        let fileURL = SharedStorage.capturesFileURL(inContainer: container)
        let capture = Capture(kind: .text, text: "A real idea")

        try await JSONFileCaptureStore(fileURL: fileURL).add(capture)

        #expect(try await JSONFileCaptureStore(fileURL: fileURL).all() == [capture])
    }

    @Test func removeLegacyCapturesDeletesOnlyTheLegacyFile() async throws {
        let container = try containerWithLegacyCaptures()
        let fileURL = SharedStorage.capturesFileURL(inContainer: container)
        let capture = Capture(kind: .text, text: "A real idea")
        try await JSONFileCaptureStore(fileURL: fileURL).add(capture)

        try SharedStorage.removeLegacyCaptures(inContainer: container)

        #expect(!FileManager.default.fileExists(atPath: legacyFileURL(in: container).path))
        #expect(try await JSONFileCaptureStore(fileURL: fileURL).all() == [capture])
    }

    @Test func removeLegacyCapturesDoesNothingWhenItIsGone() throws {
        let container = try containerWithLegacyCaptures()

        try SharedStorage.removeLegacyCaptures(inContainer: container)
        try SharedStorage.removeLegacyCaptures(inContainer: container)

        #expect(!FileManager.default.fileExists(atPath: legacyFileURL(in: container).path))
    }
}
