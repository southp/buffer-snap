import Foundation

/// A `CaptureStore` that keeps captures in a JSON file.
///
/// It caches nothing and reads the file on every call, so a store always sees what another store wrote. Writes are
/// atomic, so a reader never sees half a file. Two processes writing at the same moment could still lose one of the
/// writes, so only the app's process writes, through one instance: `docs/decisions/46-no-file-coordination.md`.
public actor JSONFileCaptureStore: CaptureStore {
    private let fileURL: URL

    /// Creates a store on `fileURL`. A missing file reads as no captures.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Every stored capture, newest first.
    public func all() throws -> [Capture] {
        try read().sorted { $0.createdAt > $1.createdAt }
    }

    public func add(_ capture: Capture) throws {
        try write(read() + [capture])
    }

    public func delete(id: Capture.ID) throws {
        let captures = try read()
        let remaining = captures.filter { $0.id != id }
        if remaining.count != captures.count {
            try write(remaining)
        }
    }

    public func deleteSubmitted() throws {
        let captures = try read()
        let remaining = captures.filter { $0.status != .submitted }
        if remaining.count != captures.count {
            try write(remaining)
        }
    }

    public func setStatus(_ status: Capture.Status, failure: Capture.Failure?, ids: Set<Capture.ID>) throws {
        var captures = try read()
        var didChange = false
        for index in captures.indices where ids.contains(captures[index].id) {
            captures[index].status = status
            captures[index].failure = status == .failed ? failure : nil
            didChange = true
        }
        if didChange {
            try write(captures)
        }
    }

    public func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) throws {
        var captures = try read()
        var didChange = false
        for index in captures.indices where captures[index].batchID == nil {
            if let batchID = batchIDs[captures[index].id] {
                captures[index].batchID = batchID
                didChange = true
            }
        }
        if didChange {
            try write(captures)
        }
    }

    private func read() throws -> [Capture] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
        return try JSONDecoder().decode([Capture].self, from: data)
    }

    private func write(_ captures: [Capture]) throws {
        try JSONEncoder().encode(captures).write(to: fileURL, options: .atomic)
    }
}
