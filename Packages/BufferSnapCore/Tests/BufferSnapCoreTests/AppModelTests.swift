import BufferSnapCore
import Testing

@MainActor
struct AppModelTests {
    @Test func startsSignedOut() {
        let model = AppModel(auth: MockAuthService())

        #expect(model.route == .signedOut)
    }

    @Test func signInRoutesToCaptures() async {
        let model = AppModel(auth: MockAuthService())

        await model.signIn()

        #expect(model.route == .captures)
    }

    @Test func failedSignInStaysSignedOut() async {
        let model = AppModel(auth: FailingAuthService())

        await model.signIn()

        #expect(model.route == .signedOut)
    }
}
