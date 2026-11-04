import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// Throwaway (#10): every surface in the matrix, named so the checklist can refer to it.

struct SpikeEntry: TimelineEntry {
    let date: Date
    let lock: String
    let runs: Int
}

struct SpikeProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry {
        SpikeEntry(date: .now, lock: "?", runs: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SpikeEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SpikeEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> SpikeEntry {
        let runs = SpikeLog.read().split(separator: "\n").count
        return SpikeEntry(date: .now, lock: SpikeLog.lockState(), runs: runs)
    }
}

struct SpikeTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "spike.today", provider: SpikeProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text("Spike: \(entry.runs) logged, \(entry.lock)").font(.caption)
                HStack {
                    Button("Default", intent: SpikeDefaultIntent(surface: "today"))
                    Button("Always", intent: SpikeAlwaysIntent(surface: "today"))
                    Button("Text", intent: SpikeTextIntent(surface: "today"))
                }
                .font(.caption)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spike Today")
        .description("Tap each button from the Today View")
        .supportedFamilies([.systemMedium])
    }
}

/// One circular Lock Screen widget per kind of action.
struct SpikeLockCircle<Intent: AppIntent>: View {
    let label: String
    let intent: Intent

    var body: some View {
        Button(intent: intent) {
            Text(label).font(.caption2)
        }
        .buttonStyle(.plain)
        .containerBackground(.clear, for: .widget)
    }
}

struct SpikeLockDefaultWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "spike.lock.default", provider: SpikeProvider()) { _ in
            SpikeLockCircle(label: "Def", intent: SpikeDefaultIntent(surface: "lockwidget"))
        }
        .configurationDisplayName("Spike Def")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SpikeLockAlwaysWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "spike.lock.always", provider: SpikeProvider()) { _ in
            SpikeLockCircle(label: "Alw", intent: SpikeAlwaysIntent(surface: "lockwidget"))
        }
        .configurationDisplayName("Spike Alw")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SpikeLockTextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "spike.lock.text", provider: SpikeProvider()) { _ in
            SpikeLockCircle(label: "Txt", intent: SpikeTextIntent(surface: "lockwidget"))
        }
        .configurationDisplayName("Spike Txt")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SpikeControlDefault: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.default") {
            ControlWidgetButton(action: SpikeDefaultIntent(surface: "control")) {
                Label("S1 Default", systemImage: "1.circle")
            }
        }
        .displayName("S1 Default")
    }
}

struct SpikeControlAlways: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.always") {
            ControlWidgetButton(action: SpikeAlwaysIntent(surface: "control")) {
                Label("S2 Always", systemImage: "2.circle")
            }
        }
        .displayName("S2 Always")
    }
}

struct SpikeControlText: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.text") {
            ControlWidgetButton(action: SpikeTextInAppIntent()) {
                Label("S3 Text", systemImage: "3.circle")
            }
        }
        .displayName("S3 Text")
    }
}

struct SpikeControlTextDefault: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.textdefault") {
            ControlWidgetButton(action: SpikeTextRequiredIntent()) {
                Label("S4 Text required", systemImage: "4.circle")
            }
        }
        .displayName("S4 Text required")
    }
}

struct SpikeControlOpenApp: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.openapp") {
            ControlWidgetButton(action: SpikeOpenAppIntent(surface: "control")) {
                Label("S5 Open app", systemImage: "5.circle")
            }
        }
        .displayName("S5 Open app")
    }
}

struct SpikeControlCamera: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.camera") {
            ControlWidgetButton(action: SpikeCameraIntent()) {
                Label("S6 Camera", systemImage: "camera")
            }
        }
        .displayName("S6 Camera")
    }
}

struct SpikeControlAudio: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "spike.control.audio") {
            ControlWidgetButton(action: SpikeAudioStartIntent()) {
                Label("S7 Record", systemImage: "mic")
            }
        }
        .displayName("S7 Record")
    }
}

struct SpikeAudioLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpikeAudioAttributes.self) { context in
            HStack {
                Text(context.state.startedAt, style: .timer)
                Spacer()
                Button("Stop", intent: SpikeAudioStopIntent())
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Button("Stop", intent: SpikeAudioStopIntent())
                }
            } compactLeading: {
                Image(systemName: "mic")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer).frame(width: 40)
            } minimal: {
                Image(systemName: "mic")
            }
        }
    }
}

@main
struct SpikeWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapperWidget()
        SpikeTodayWidget()
        SpikeLockDefaultWidget()
        SpikeLockAlwaysWidget()
        SpikeLockTextWidget()
        SpikeControlDefault()
        SpikeControlAlways()
        SpikeControlText()
        SpikeControlTextDefault()
        SpikeControlOpenApp()
        SpikeControlCamera()
        SpikeControlAudio()
        SpikeAudioLiveActivity()
    }
}
