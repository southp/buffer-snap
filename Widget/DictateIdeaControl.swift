import SwiftUI
import WidgetKit

/// The control for Control Center, the Action button and the Lock Screen's bottom buttons: one press starts listening,
/// without opening the app, and the next one stops.
struct DictateIdeaControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "DictateIdeaControl") {
            ControlWidgetButton(action: DictateIdeaIntent()) {
                Label("Dictate an Idea", image: "bufsnap.dictate")
            }
        }
        .displayName("Dictate an Idea")
        .description("Saves what you say as an idea, without opening BufSnap. Press again to stop.")
    }
}
