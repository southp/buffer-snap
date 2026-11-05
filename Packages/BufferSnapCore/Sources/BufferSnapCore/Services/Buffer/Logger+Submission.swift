import OSLog

extension Logger {
    /// What the submission queue does. Never log a token, a capture's text or a message from Buffer through this.
    static let submission = Logger(subsystem: "me.southp.buffersnap", category: "submission")
}
