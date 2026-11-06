import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// Throwaway spike: one control per experiment, named so the device checklist can refer to them.

struct T1DictateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.t1.dictate") {
            ControlWidgetButton(action: T1DictateIntent(source: "control")) {
                Label("T1 Dictate", systemImage: "mic.fill")
            }
        }
        .displayName("T1 Dictate")
        .description("Spike: dictate without opening the app.")
    }
}

struct T2TypeInAppControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.t2.type-app") {
            ControlWidgetButton(action: T2TypeInAppIntent()) {
                Label("T2 Type (app)", systemImage: "2.circle")
            }
        }
        .displayName("T2 Type (app)")
        .description("Spike: a text box, run in the app's process.")
    }
}

struct T3TypeInWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.t3.type-widget") {
            ControlWidgetButton(action: T3TypeInWidgetIntent()) {
                Label("T3 Type (widget)", systemImage: "3.circle")
            }
        }
        .displayName("T3 Type (widget)")
        .description("Spike: a text box, run in the widget's process.")
    }
}

struct T4NotifyControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.t4.notify") {
            ControlWidgetButton(action: T4NotifyIntent()) {
                Label("T4 Notify", systemImage: "4.circle")
            }
        }
        .displayName("T4 Type via notification")
        .description("Spike: reply to a notification.")
    }
}

struct T5RequiredControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.t5.required") {
            ControlWidgetButton(action: T5RequiredIntent()) {
                Label("T5 Required", systemImage: "5.circle")
            }
        }
        .displayName("T5 Required idea")
        .description("Spike: a required parameter.")
    }
}

/// T1 on the Home Screen: a widget whose only button dictates.
struct SpikeDictateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "spike.dictate", provider: SpikeEmptyProvider()) { _ in
            Button(intent: T1DictateIntent(source: "widget")) {
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.largeTitle)
                    Text("Dictate")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("T1 Dictate")
        .description("Spike: dictate without opening the app.")
        .supportedFamilies([.systemSmall])
    }
}

struct SpikeEmptyEntry: TimelineEntry {
    let date: Date
}

struct SpikeEmptyProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEmptyEntry {
        SpikeEmptyEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SpikeEmptyEntry) -> Void) {
        completion(SpikeEmptyEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SpikeEmptyEntry>) -> Void) {
        completion(Timeline(entries: [SpikeEmptyEntry(date: .now)], policy: .never))
    }
}

/// T1's Live Activity, on the Lock Screen and in the Dynamic Island, with the words so far and a Stop button.
struct T1DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: T1DictationAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(context.state.status, systemImage: "mic.fill")
                        .font(.headline)
                    Spacer()
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                        .frame(width: 56)
                    Button(intent: T1StopIntent()) {
                        Text("Stop")
                    }
                    .tint(.red)
                }
                Text(context.state.text.isEmpty ? "Say something…" : context.state.text)
                    .font(.body)
                    .lineLimit(3)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.status, systemImage: "mic.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: T1StopIntent()) {
                        Text("Stop")
                    }
                    .tint(.red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.text.isEmpty ? "Say something…" : context.state.text)
                        .lineLimit(3)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .frame(width: 40)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}
