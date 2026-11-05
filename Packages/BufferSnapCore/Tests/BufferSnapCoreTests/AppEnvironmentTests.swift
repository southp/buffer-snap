import BufferSnapCore
import Testing

struct AppEnvironmentTests {
    @Test func mockStoreStartsWithSeed() async throws {
        let seed = [Capture(kind: .photo, text: "Seeded")]
        let environment = AppEnvironment.mock(seed: seed)

        #expect(try await environment.captureStore.all() == seed)
    }

    /// The environment's queue works on its own store and auth: nothing else may build another.
    @Test func theQueueUsesTheEnvironmentsServices() async throws {
        let environment = AppEnvironment.mock(seed: [Capture(kind: .text, text: "An idea")])
        try await environment.auth.signIn()

        await environment.submissions.run()

        #expect(try await environment.captureStore.all().map(\.status) == [.submitted])
    }

    @Test func mockSignInSucceeds() async throws {
        let environment = AppEnvironment.mock(seed: [])

        try await environment.auth.signIn()
    }

    @Test func mockSpeechIsAllowedToListen() async {
        let environment = AppEnvironment.mock(seed: [])

        #expect(await environment.speech.permission() == .granted)
    }
}
