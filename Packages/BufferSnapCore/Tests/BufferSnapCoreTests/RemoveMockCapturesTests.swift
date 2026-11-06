import BufferSnapCore
import Foundation
import Synchronization
import Testing

/// An install that tapped the widget's mock buttons between #40 and #41: its file holds both mocks and real captures.
struct RemoveMockCapturesTests {
    /// Counts `onChange` calls.
    private final class ChangeCounter: Sendable {
        private let count = Mutex(0)

        var value: Int {
            count.withLock { $0 }
        }

        func increment() {
            count.withLock { $0 += 1 }
        }
    }

    private let mocks = [
        Capture(kind: .text, text: "Mock text capture"),
        Capture(kind: .photo, text: "Mock photo capture"),
    ]

    /// Real captures, including the closest ones to a mock.
    private let real = [
        Capture(kind: .text, createdAt: .now.addingTimeInterval(-1), text: "A real idea"),
        Capture(kind: .text, createdAt: .now.addingTimeInterval(-2), text: "Mock text capture of a mock interview"),
        Capture(kind: .text, createdAt: .now.addingTimeInterval(-3), text: "mock text capture"),
        Capture(kind: .text, createdAt: .now.addingTimeInterval(-4), text: "Mock photo capture"),
        Capture(kind: .photo, createdAt: .now.addingTimeInterval(-5)),
    ]

    @Test func removesMocksAndKeepsEverythingElse() async throws {
        let store = InMemoryCaptureStore(seed: mocks + real)

        try await store.removeMockCaptures()

        #expect(try await store.all() == real)
    }

    @Test func removesMocksFromTheFileTheAppAndWidgetShare() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = JSONFileCaptureStore(fileURL: fileURL)
        for capture in mocks + real {
            try await store.add(capture)
        }

        try await store.removeMockCaptures()

        #expect(try await JSONFileCaptureStore(fileURL: fileURL).all() == real)
    }

    @Test func reloadsTheWidgetOnlyWhenItRemovesSomething() async throws {
        let counter = ChangeCounter()
        let store = NotifyingCaptureStore(base: InMemoryCaptureStore(seed: real + mocks), onChange: counter.increment)

        try await store.removeMockCaptures()
        #expect(counter.value == mocks.count)

        try await store.removeMockCaptures()
        #expect(counter.value == mocks.count)
    }

    @Test func aMissingFileIsNothingToRemove() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = JSONFileCaptureStore(fileURL: fileURL)

        try await store.removeMockCaptures()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    /// An unreadable file stays as it is, and the app tries again at the next launch.
    @Test func anUnreadableFileThrowsAndStaysAsItIs() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let unreadable = Data("not JSON".utf8)
        try unreadable.write(to: fileURL)

        await #expect(throws: (any Error).self) {
            try await JSONFileCaptureStore(fileURL: fileURL).removeMockCaptures()
        }
        #expect(try Data(contentsOf: fileURL) == unreadable)
    }
}
