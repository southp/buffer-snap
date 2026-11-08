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
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.headline)
                if let detail {
                    detail
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(isSyncing ? "Syncing…" : "Sync now", action: onSyncNow)
                .buttonStyle(.bordered)
                .controlSize(.small)
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
            "checkmark.circle.fill"
        case .waiting:
            "clock.fill"
        case .offline:
            "wifi.slash"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .nothingYet, .allSent:
            .green
        case .waiting:
            .orange
        case .offline:
            .secondary
        case .failed:
            .red
        }
    }
}

/// Something the list couldn't do, under the sync status until the next try works.
struct CaptureListProblemRow: View {
    let problem: CaptureListModel.Problem

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
        .font(.subheadline)
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
        }
    }
}
