import Testing

@testable import BufferSnap

/// The intent the control and widgets run. `@MainActor` and serialized because `onRun` is one shared closure.
@MainActor
@Suite(.serialized)
struct OpenCaptureIntentTests {
    /// The app's copy. The widget's snapshot tests compile their own copy of the intent into this test module.
    private typealias Intent = BufferSnap.OpenCaptureIntent

    /// Without this the system runs the intent in the background, and the app never opens.
    @Test func opensTheApp() {
        #expect(Intent.openAppWhenRun)
    }

    /// The test host is the app, so its launch has already connected the intent to `AppModel`.
    @Test func theAppSetsTheHookAtLaunch() {
        #expect(Intent.onRun != nil)
    }

    /// The navigation itself is `AppModel.showCapture()`, covered in Core.
    @Test func runningItCallsTheHookOnce() async throws {
        let original = Intent.onRun
        defer {
            Intent.onRun = original
        }
        var runs = 0
        Intent.onRun = {
            runs += 1
        }

        _ = try await Intent().perform()

        #expect(runs == 1)
    }

    /// What happens in the widget's process, where nothing sets the hook.
    @Test func runningItWithoutAHookDoesNothing() async throws {
        let original = Intent.onRun
        defer {
            Intent.onRun = original
        }
        Intent.onRun = nil

        _ = try await Intent().perform()
    }
}
