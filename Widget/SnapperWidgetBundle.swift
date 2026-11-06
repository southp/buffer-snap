import SwiftUI
import WidgetKit

/// Everything this extension adds to the system.
@main
struct SnapperWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapperWidget()
        OpenCaptureControl()
        // Throwaway spike: capturing without opening the app.
        T1DictateControl()
        T2TypeInAppControl()
        T3TypeInWidgetControl()
        T4NotifyControl()
        T5RequiredControl()
        SpikeDictateWidget()
        T1DictationLiveActivity()
    }
}
