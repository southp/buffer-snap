import OSLog

extension Logger {
    /// Sign-in and token refresh events. Never log a token, an authorization code or a `state` through this.
    static let auth = Logger(subsystem: "me.southp.buffersnap", category: "auth")
}
