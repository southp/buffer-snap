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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: capture.kind.symbolName)
                .font(.inter(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityLabel(capture.kind.displayName)
                // Without text, the title already is the kind's name; don't read it twice.
                .accessibilityHidden(title == capture.kind.displayName)
            VStack(alignment: .leading, spacing: 4) {
                // In full: it's the only place to check what was heard before it reaches Buffer.
                Text(title)
                    .font(.inter(.body))
                    .foregroundStyle(Theme.ink)
                Text(relativeTimestamp)
                    .font(.inter(.footnote))
                    .foregroundStyle(Theme.muted)
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

/// A capture's status as a pill: Sun while it waits, Mint once it's in Buffer, Tomato if it didn't get there.
private struct CaptureStatusBadge: View {
    let status: Capture.Status

    var body: some View {
        Pill(text: Text(label), fill: fill)
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

    private var fill: Color {
        switch status {
        case .pending:
            Theme.sun
        case .submitted:
            Theme.mint
        case .failed:
            Theme.tomato
        }
    }
}

extension Capture.Kind {
    /// The SF Symbol shown for this kind.
    fileprivate var symbolName: String {
        switch self {
        case .text:
            "textformat"
        case .photo:
            "camera"
        }
    }

    /// The name shown when a capture has no text.
    fileprivate var displayName: String {
        switch self {
        case .text:
            "Text"
        case .photo:
            "Photo"
        }
    }
}
