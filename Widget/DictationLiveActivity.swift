import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity of a dictation started outside the app, on the Lock Screen and in the Dynamic Island. The app
/// starts, updates and ends it (`LiveActivityDictationDisplay`); this only draws it.
struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationActivityAttributes.self) { context in
            DictationActivityView(status: context.state)
        } dynamicIsland: { context in
            let status = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DictationTitle(status: status)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if status.isListening {
                        HStack(spacing: 8) {
                            DictationTimer(status: status)
                            DictationStopButton()
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(status.detail)
                        .foregroundStyle(status.words.isEmpty ? .secondary : .primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: status.symbolName)
                    .foregroundStyle(status.tint)
            } compactTrailing: {
                if status.isListening {
                    DictationTimer(status: status)
                        .frame(width: 40)
                } else {
                    Text(status.title)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } minimal: {
                Image(systemName: status.symbolName)
                    .foregroundStyle(status.tint)
            }
        }
    }
}
