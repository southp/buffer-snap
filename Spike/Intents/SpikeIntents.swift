import AppIntents
import BufferSnapCore

/// Throwaway (#10): the same action with each authentication policy, recording where and how it ran.
enum SpikeAction {
    static func run(_ event: String, surface: String, detail: String = "") async {
        SpikeLog.write(event, surface: surface, detail: "\(detail) store=\(await storeWrite())")
    }

    /// Whether the real capture store can be written from here.
    private static func storeWrite() async -> String {
        do {
            let store = JSONFileCaptureStore(fileURL: try SharedStorage.capturesFileURL())
            try await store.add(.mock(kind: .text))
            return "ok"
        } catch {
            return "FAILED(\(error.localizedDescription))"
        }
    }
}

struct SpikeDefaultIntent: AppIntent {
    static let title: LocalizedStringResource = "Spike default"
    static let isDiscoverable = false

    @Parameter(title: "Surface")
    var surface: String

    init() {}

    init(surface: String) {
        self.surface = surface
    }

    func perform() async throws -> some IntentResult {
        await SpikeAction.run("default", surface: surface)
        return .result()
    }
}

struct SpikeAlwaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Spike always"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Surface")
    var surface: String

    init() {}

    init(surface: String) {
        self.surface = surface
    }

    func perform() async throws -> some IntentResult {
        await SpikeAction.run("always", surface: surface)
        return .result()
    }
}

struct SpikeTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Spike text"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Surface", default: "shortcut")
    var surface: String

    @Parameter(title: "Idea")
    var idea: String?

    init() {}

    init(surface: String) {
        self.surface = surface
    }

    func perform() async throws -> some IntentResult {
        SpikeLog.write("text-start", surface: surface)
        do {
            let value: String
            if let idea {
                value = idea
            } else {
                value = try await $idea.requestValue("What's the idea?")
            }
            await SpikeAction.run("text-done", surface: surface, detail: "chars=\(value.count)")
        } catch {
            SpikeLog.write("text-error", surface: surface, detail: "\(error)")
            throw error
        }
        return .result()
    }
}

struct SpikeTextDefaultIntent: AppIntent {
    static let title: LocalizedStringResource = "Spike text default"
    static let isDiscoverable = false

    @Parameter(title: "Surface")
    var surface: String

    @Parameter(title: "Idea")
    var idea: String?

    init() {}

    init(surface: String) {
        self.surface = surface
    }

    func perform() async throws -> some IntentResult {
        SpikeLog.write("textdefault-start", surface: surface)
        do {
            let value: String
            if let idea {
                value = idea
            } else {
                value = try await $idea.requestValue("What's the idea?")
            }
            await SpikeAction.run("textdefault-done", surface: surface, detail: "chars=\(value.count)")
        } catch {
            SpikeLog.write("textdefault-error", surface: surface, detail: "\(error)")
            throw error
        }
        return .result()
    }
}

struct SpikeOpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Spike open app"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Surface")
    var surface: String

    init() {}

    init(surface: String) {
        self.surface = surface
    }

    func perform() async throws -> some IntentResult {
        await SpikeAction.run("openapp", surface: surface)
        return .result()
    }
}
