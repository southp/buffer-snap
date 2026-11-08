import BufferSnapCore
import OSLog
import SwiftUI
import WidgetKit

struct SnapperWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStorage.widgetKind, provider: CaptureCountProvider()) { entry in
            SnapperWidgetFace(count: entry.count)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Snapper")
        .description("Capture an idea in one tap")
        .supportedFamilies([.systemMedium, .accessoryCircular])
    }
}

/// Picks the face for where the widget is placed.
private struct SnapperWidgetFace: View {
    @Environment(\.widgetFamily) private var family
    let count: Int

    var body: some View {
        switch family {
        case .accessoryCircular:
            SnapperLockScreenView()
        default:
            SnapperWidgetView(waitingCount: count)
        }
    }
}

struct CaptureCountEntry: TimelineEntry {
    let date: Date
    let count: Int
}

/// Reads how many captures are waiting to send from the shared store.
///
/// The count only changes on a store write, and each write reloads the timeline, so a timeline is one entry that never
/// expires by itself.
struct CaptureCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureCountEntry {
        CaptureCountEntry(date: .now, count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CaptureCountEntry) -> Void) {
        Task {
            completion(await currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CaptureCountEntry>) -> Void) {
        Task {
            completion(Timeline(entries: [await currentEntry()], policy: .never))
        }
    }

    private func currentEntry() async -> CaptureCountEntry {
        CaptureCountEntry(date: .now, count: await captureCount())
    }

    private func captureCount() async -> Int {
        do {
            let captures = try await JSONFileCaptureStore(fileURL: SharedStorage.capturesFileURL()).all()
            return SyncStatus.waitingCount(of: captures)
        } catch {
            Logger().error("Can't read the shared capture store: \(error)")
            return 0
        }
    }
}
