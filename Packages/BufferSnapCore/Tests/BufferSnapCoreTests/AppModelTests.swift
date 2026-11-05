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
        let model = AppModel(auth: FailingAuthService())

        await model.signIn()

        #expect(model.route == .signedOut)
    }

    @Test func showCaptureStaysOnTheCaptureScreen() async {
        let model = AppModel(auth: MockAuthService())
        await model.signIn()

        model.showCapture()

        #expect(model.route == .capture)
    }

    /// A cold launch from a control: the intent can run before the app is past sign-in, and must still end on capture.
    @Test func askingForCaptureWhileSigningInStillEndsOnCapture() async {
        let auth = HeldAuthService()
        let model = AppModel(auth: auth)
        let signIn = Task {
            await model.signIn()
        }
        await auth.waitForSignIn()

        model.showCapture()
        #expect(model.route == .signedOut)

        await auth.finishSignIn()
        await signIn.value
        #expect(model.route == .capture)
    }

    @Test func askingForCaptureBeforeSigningInStillEndsOnCapture() async {
        let model = AppModel(auth: MockAuthService())

        model.showCapture()
        await model.signIn()

        #expect(model.route == .capture)
    }
}

/// An `AuthService` whose sign-in waits until the test lets it finish.
private actor HeldAuthService: AuthService {
    private var started: CheckedContinuation<Void, Never>?
    private var finish: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func signIn() async {
        hasStarted = true
        started?.resume()
        await withCheckedContinuation { finish = $0 }
    }

    func waitForSignIn() async {
        if !hasStarted {
            await withCheckedContinuation { started = $0 }
        }
    }

    func finishSignIn() {
        finish?.resume()
    }
}
