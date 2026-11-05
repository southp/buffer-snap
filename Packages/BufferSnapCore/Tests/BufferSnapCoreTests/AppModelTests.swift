import BufferSnapCore
import Testing

@MainActor
struct AppModelTests {
    @Test func startsSignedOut() {
        let model = AppModel(auth: MockAuthService())

        #expect(model.route == .signedOut)
    }

    @Test func signInRoutesToTheCaptureScreen() async {
        let model = AppModel(auth: MockAuthService())

        await model.signIn()

        #expect(model.route == .capture)
    }

    @Test func captureListAndCaptureScreenAreOneStepApart() async {
        let model = AppModel(auth: MockAuthService())
        await model.signIn()

        model.showCaptureList()
        #expect(model.route == .captureList)

        model.showCapture()
        #expect(model.route == .capture)
    }

    @Test func nothingLeavesSignedOutButSigningIn() {
        let model = AppModel(auth: MockAuthService())

        model.showCaptureList()
        #expect(model.route == .signedOut)

        model.showCapture()
        #expect(model.route == .signedOut)
    }

    @Test func failedSignInStaysSignedOut() async {
        let model = AppModel(auth: StubAuthService(signInError: TestError()))

        await model.signIn()

        #expect(model.route == .signedOut)
    }
}
