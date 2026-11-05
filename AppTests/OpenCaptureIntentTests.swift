import Testing

@testable import BufferSnap

/// The intent the control and widgets run. `@MainActor` and serialized because `onRun` is one shared closure.
@MainActor
@Suite(.serialized)
struct OpenCaptureIntentTests {
    /// Without this the system runs the intent in the background, and the app never opens.
    @Test func opensTheApp() {
        #expect(OpenCaptureIntent.openAppWhenRun)
    }

    /// The test host is the app, so its launch has already connected the intent to `AppModel`.
    @Test func theAppSetsTheHookAtLaunch() {
        #expect(OpenCaptureIntent.onRun != nil)
    }

    /// The navigation itself is `AppModel.showCapture()`, covered in Core.
    @Test func runningItCallsTheHookOnce() async throws {
        let original = OpenCaptureIntent.onRun
        defer {
            OpenCaptureIntent.onRun = original
        }
        var runs = 0
        OpenCaptureIntent.onRun = {
            runs += 1
        }

        _ = try await OpenCaptureIntent().perform()

        #expect(runs == 1)
    }

    /// What happens in the widget's process, where nothing sets the hook.
    @Test func runningItWithoutAHookDoesNothing() async throws {
        let original = OpenCaptureIntent.onRun
        defer {
            OpenCaptureIntent.onRun = original
        }
        OpenCaptureIntent.onRun = nil

        _ = try await OpenCaptureIntent().perform()
    }
}
