import BufferSnapCore
import Foundation
import Testing

struct JSONFileCaptureStoreTests {
    /// A path in a fresh temp directory, with no file at it yet.
    private func missingFileURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("captures.json")
    }

    @Test func missingFileReadsAsEmpty() async throws {
        let store = JSONFileCaptureStore(fileURL: try missingFileURL())

        #expect(try await store.all().isEmpty)
    }

    @Test func addAllDeleteRoundTrip() async throws {
        let store = JSONFileCaptureStore(fileURL: try missingFileURL())
        let kept = Capture.at(1, kind: .photo)
        let deleted = Capture.at(2, kind: .photo)

        try await store.add(kept)
        try await store.add(deleted)
        #expect(try await store.all() == [deleted, kept])

        try await store.delete(id: deleted.id)
        #expect(try await store.all() == [kept])
    }

    @Test func allReturnsNewestFirst() async throws {
        let store = JSONFileCaptureStore(fileURL: try missingFileURL())
        let oldest = Capture.at(1)
        let middle = Capture.at(2)
        let newest = Capture.at(3)

        try await store.add(middle)
        try await store.add(newest)
        try await store.add(oldest)

        #expect(try await store.all() == [newest, middle, oldest])
    }

    // The app and the widget are two processes with a store each, so neither may answer from a cache.
    @Test func storesOnTheSameFileSeeEachOthersWrites() async throws {
        let fileURL = try missingFileURL()
        let app = JSONFileCaptureStore(fileURL: fileURL)
        let widget = JSONFileCaptureStore(fileURL: fileURL)
        let capture = Capture(kind: .photo)

        #expect(try await app.all().isEmpty)
        try await widget.add(capture)
        #expect(try await app.all() == [capture])

        try await app.delete(id: capture.id)
        #expect(try await widget.all().isEmpty)
    }

    @Test func deleteUnknownIDLeavesMissingFileMissing() async throws {
        let fileURL = try missingFileURL()
        let store = JSONFileCaptureStore(fileURL: fileURL)

        try await store.delete(id: UUID())

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    // A file we can't read may still hold captures, so a write must fail rather than replace it.
    @Test func corruptFileThrowsAndIsNotOverwritten() async throws {
        let fileURL = try missingFileURL()
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: fileURL)
        let store = JSONFileCaptureStore(fileURL: fileURL)

        await #expect(throws: (any Error).self) {
            try await store.all()
        }
        await #expect(throws: (any Error).self) {
            try await store.add(Capture(kind: .text))
        }
        #expect(try Data(contentsOf: fileURL) == corrupt)
    }
}
