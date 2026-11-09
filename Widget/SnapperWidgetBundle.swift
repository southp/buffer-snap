import SwiftUI
import WidgetKit

/// Everything this extension adds to the system.
@main
struct SnapperWidgetBundle: WidgetBundle {
    var body: some Widget {
        DictateIdeaControl()
        DictateWidget()
        DictationLiveActivity()
    }
}
