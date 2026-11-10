import BufferSnapCore
import SwiftUI

/// The top of the capture list: whether everything reached Buffer, and Sync now.
struct SyncStatusRow: View {
    let status: SyncStatus
    /// Whether a Sync now is running, which the button says instead of offering another.
    let isSyncing: Bool
    /// Called when the user asks to send everything that can go.
    let onSyncNow: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Badge(fill: badgeFill) {
                Image(systemName: symbolName)
                    .font(.inter(.subheadline, weight: .bold))
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.inter(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    detail
                        .font(.inter(.footnote))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 8)
            Button(isSyncing ? "Syncing…" : "Sync now", action: onSyncNow)
                .buttonStyle(.paperInkSecondary)
                .disabled(isSyncing || !status.canSyncNow)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: Text {
        switch status {
        case .nothingYet, .allSent:
            Text("All sent to Buffer")
        case .waiting(let count, _):
            Text("\(count) waiting to send")
        case .offline:
            Text("Offline")
        case .failed(let count, _):
            Text("\(count) not sent")
        }
    }

    private var detail: Text? {
        switch status {
        case .nothingYet, .allSent:
            nil
        case .waiting(_, let nextSendAt?):
            Text("Next one sends at \(nextSendAt, format: .dateTime.hour().minute())")
        case .waiting(_, nil):
            Text("Sends as soon as it can")
        case .offline(let count):
            Text("\(count) will send when you're back online")
        case .failed(_, let waiting) where waiting > 0:
            Text("Tap Resend below. \(waiting) more waiting to send")
        case .failed:
            Text("Tap Resend below to try again")
        }
    }

    private var symbolName: String {
        switch status {
        case .nothingYet, .allSent:
            "checkmark"
        case .waiting:
            "clock"
        case .offline:
            "wifi.slash"
        case .failed:
            "exclamationmark"
        }
    }

    private var badgeFill: Color {
        switch status {
        case .nothingYet, .allSent:
            Theme.mint
        case .waiting:
            Theme.sun
        case .offline:
            Theme.divider
        case .failed:
            Theme.tomato
        }
    }
}

/// Something the list couldn't do, under the sync status until the next try works.
struct CaptureListProblemRow: View {
    let problem: CaptureListModel.Problem

    var body: some View {
        Label {
            Text(message)
                .foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Theme.tomatoText)
        }
        .font(.inter(.subheadline))
    }

    private var message: LocalizedStringKey {
        switch problem {
        case .couldNotLoad:
            "Can't read your captures right now, so this list may be out of date."
        case .couldNotDelete:
            "Couldn't delete that capture. Try again."
        case .couldNotResend:
            "Couldn't resend. Try again."
        case .couldNotSend:
            "Couldn't start sending. Try again."
        case .couldNotClear:
            "Couldn't clear your submitted ideas. Try again."
        }
    }
}
