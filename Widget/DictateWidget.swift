import SwiftUI
import WidgetKit

/// A small Home Screen widget that's one mic button: a press starts listening without opening the app.
struct DictateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DictateWidget", provider: DictateWidgetProvider()) { _ in
            DictateWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dictate an Idea")
        .description("Saves what you say as an idea, without opening BufSnap.")
        .supportedFamilies([.systemSmall])
    }
}

struct DictateWidgetEntry: TimelineEntry {
    let date: Date
}

/// The widget never changes, so its timeline is one entry that never expires.
struct DictateWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DictateWidgetEntry {
        DictateWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (DictateWidgetEntry) -> Void) {
        completion(DictateWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DictateWidgetEntry>) -> Void) {
        completion(Timeline(entries: [DictateWidgetEntry(date: .now)], policy: .never))
    }
}
