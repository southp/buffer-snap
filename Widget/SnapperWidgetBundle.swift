import SwiftUI
import WidgetKit

/// Everything this extension adds to the system.
@main
struct SnapperWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapperWidget()
        DictateIdeaControl()
        DictateWidget()
        DictationLiveActivity()
    }
}
