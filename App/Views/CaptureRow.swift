import BufferSnapCore
import SwiftUI

/// One capture in the list: its kind's symbol, its text (or kind name), how long ago it was made, and its status.
struct CaptureRow: View {
    let capture: Capture
    /// The moment "5 minutes ago" counts from. Passed in rather than read from the clock, so snapshots are stable.
    let now: Date

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: capture.kind.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityLabel(capture.kind.displayName)
                // Without text, the title already is the kind's name; don't read it twice.
                .accessibilityHidden(title == capture.kind.displayName)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .lineLimit(2)
                Text(relativeTimestamp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            CaptureStatusBadge(status: capture.status)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard let text = capture.text, !text.isEmpty else {
            return capture.kind.displayName
        }
        return text
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateTimeStyle = .named
        // A capture made after `now` (the clock moved on since it was read) reads "now", never "in 10 seconds".
        return formatter.localizedString(for: capture.createdAt, relativeTo: max(now, capture.createdAt))
    }
}

/// A capture's status as a small colored capsule.
private struct CaptureStatusBadge: View {
    let status: Capture.Status

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
    }

    private var label: String {
        switch status {
        case .pending:
            "Pending"
        case .submitted:
            "Submitted"
        case .failed:
            "Failed"
        }
    }

    private var tint: Color {
        switch status {
        case .pending:
            .orange
        case .submitted:
            .green
        case .failed:
            .red
        }
    }
}

extension Capture.Kind {
    /// The SF Symbol shown for this kind.
    fileprivate var symbolName: String {
        switch self {
        case .text:
            "textformat"
        case .audio:
            "mic"
        case .photo:
            "camera"
        case .video:
            "video"
        }
    }

    /// The name shown when a capture has no text.
    fileprivate var displayName: String {
        switch self {
        case .text:
            "Text"
        case .audio:
            "Audio"
        case .photo:
            "Photo"
        case .video:
            "Video"
        }
    }
}
