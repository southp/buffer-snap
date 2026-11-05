import BufferSnapCore
import Testing

struct AppEnvironmentTests {
    @Test func mockStoreStartsWithSeed() async throws {
        let seed = [Capture(kind: .photo, text: "Seeded")]
        let environment = AppEnvironment.mock(seed: seed)

        #expect(try await environment.captureStore.all() == seed)
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
