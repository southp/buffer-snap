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

    @Test func deleteSubmittedRemovesOnlyWhatWasSubmittedAndPersists() async throws {
        let fileURL = try missingFileURL()
        let store = JSONFileCaptureStore(fileURL: fileURL)
        var sent = Capture.at(1)
        sent.status = .submitted
        let waiting = Capture.at(2)
        var failed = Capture.at(3)
        failed.status = .failed
        try await store.add(sent)
        try await store.add(waiting)
        try await store.add(failed)

        try await store.deleteSubmitted()

        #expect(try await JSONFileCaptureStore(fileURL: fileURL).all() == [failed, waiting])
    }

    /// With nothing to remove there's no write, so a missing file stays missing.
    @Test func deleteSubmittedWithNothingSubmittedWritesNothing() async throws {
        let fileURL = try missingFileURL()

        try await JSONFileCaptureStore(fileURL: fileURL).deleteSubmitted()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
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

    // Neither store may answer from a cache.
    @Test func storesOnTheSameFileSeeEachOthersWrites() async throws {
        let fileURL = try missingFileURL()
        let first = JSONFileCaptureStore(fileURL: fileURL)
        let second = JSONFileCaptureStore(fileURL: fileURL)
        let capture = Capture(kind: .photo)

        #expect(try await first.all().isEmpty)
        try await second.add(capture)
        #expect(try await first.all() == [capture])

        try await first.delete(id: capture.id)
        #expect(try await second.all().isEmpty)
    }

    @Test func aFailuresReasonPersistsUntilTheStatusChanges() async throws {
        let fileURL = try missingFileURL()
        let capture = Capture.at(1)
        try await JSONFileCaptureStore(fileURL: fileURL).add(capture)

        try await JSONFileCaptureStore(fileURL: fileURL).setStatus(.failed, failure: .refused, ids: [capture.id])
        #expect(try await JSONFileCaptureStore(fileURL: fileURL).all().map(\.failure) == [.refused])

        try await JSONFileCaptureStore(fileURL: fileURL).setStatus(.submitted, ids: [capture.id])
        #expect(try await JSONFileCaptureStore(fileURL: fileURL).all().map(\.failure) == [nil])
    }

    /// A file written before failures had a reason still opens.
    @Test func aCaptureSavedWithoutAReasonReadsAsNone() async throws {
        let fileURL = try missingFileURL()
        let json = #"[{"id":"00000000-0000-0000-0000-000000000001","kind":"text","createdAt":0,"status":"failed"}]"#
        try Data(json.utf8).write(to: fileURL)

        let captures = try await JSONFileCaptureStore(fileURL: fileURL).all()

        #expect(captures.map(\.status) == [.failed])
        #expect(captures.map(\.failure) == [nil])
    }

    @Test func setStatusChangesOnlyTheNamedCapturesAndPersists() async throws {
        let fileURL = try missingFileURL()
        let store = JSONFileCaptureStore(fileURL: fileURL)
        let sent = Capture.at(1)
        let alsoSent = Capture.at(2)
        let waiting = Capture.at(3)
        for capture in [sent, alsoSent, waiting] {
            try await store.add(capture)
        }

        try await store.setStatus(.submitted, ids: [sent.id, alsoSent.id])

        let reopened = try await JSONFileCaptureStore(fileURL: fileURL).all()
        #expect(reopened.map(\.status) == [.pending, .submitted, .submitted])
    }

    /// A capture deleted while its upload ran stays deleted when the upload finishes.
    @Test func setStatusOfADeletedCaptureDoesNotBringItBack() async throws {
        let store = JSONFileCaptureStore(fileURL: try missingFileURL())
        let capture = Capture.at(1)
        try await store.add(capture)
        try await store.delete(id: capture.id)

        try await store.setStatus(.submitted, ids: [capture.id])

        #expect(try await store.all().isEmpty)
    }

    @Test func assignBatchesChangesOnlyTheNamedCapturesAndPersists() async throws {
        let fileURL = try missingFileURL()
        let store = JSONFileCaptureStore(fileURL: fileURL)
        let older = Capture.at(1)
        let newer = Capture.at(2)
        try await store.add(older)
        try await store.add(newer)

        try await store.assignBatches([older.id: older.id])

        let reopened = try await JSONFileCaptureStore(fileURL: fileURL).all()
        #expect(reopened.map(\.batchID) == [nil, older.id])
    }

    /// A batch stays the same once it's closed, whoever else tries to close the capture into another.
    @Test func assignBatchesLeavesACaptureThatsAlreadyInABatch() async throws {
        let store = JSONFileCaptureStore(fileURL: try missingFileURL())
        let capture = Capture.at(1)
        let first = UUID()
        try await store.add(capture)

        try await store.assignBatches([capture.id: first])
        try await store.assignBatches([capture.id: UUID()])

        #expect(try await store.all().map(\.batchID) == [first])
    }

    /// The whole way through, from a file an install before batching wrote: what was sent or failed stays as it was,
    /// and what was pending goes in a batch like anything else.
    @Test func anInstallFromBeforeBatchesCarriesOn() async throws {
        let fileURL = try missingFileURL()
        func entry(_ id: Int, _ status: String, _ createdAt: Int) -> String {
            let uuid = "00000000-0000-0000-0000-00000000000\(id)"
            return #"{"id":"\#(uuid)","kind":"text","createdAt":\#(createdAt),"status":"\#(status)","text":"\#(id)"}"#
        }
        let entries =
            [entry(1, "submitted", 0), entry(2, "submitted", 1), entry(3, "failed", 2)]
            + [entry(4, "pending", 3), entry(5, "pending", 4)]
        try Data("[\(entries.joined(separator: ","))]".utf8).write(to: fileURL)
        let store = JSONFileCaptureStore(fileURL: fileURL)
        let fixture = QueueFixture()
        let queue = fixture.makeQueue(store: store, window: 300)

        await queue.run()

        #expect(await fixture.server.ideaTexts == ["4\n\n5"])
        let batches = queue.batches(of: try await store.all())
        #expect(batches.map(\.state) == [.submitted, .submitted, .failed, .submitted])
        #expect(batches.map(\.captures.count) == [1, 1, 1, 2])
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
