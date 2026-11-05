import BufferSnapCore
import SwiftUI

/// What's above a batch in the list: when it goes or what became of it, and what can be done about that.
struct CaptureBatchHeader: View {
    let batch: CaptureBatch
    /// The moment that decides whether the batch is still counting down. Passed in, so snapshots are stable.
    let now: Date
    /// Called when the user asks to send the open batch without waiting.
    let onSendNow: () -> Void
    /// Called when the user asks to send a failed batch again.
    let onResend: () -> Void

    var body: some View {
        switch batch.state {
        case .open(let sendsAt) where batch.isWaiting(at: now):
            row(Text("Sends at \(sendsAt, format: .dateTime.hour().minute())"), action: "Send now", onSendNow)
        case .open, .closed:
            row(Text("Waiting to send"))
        case .failed:
            row(Text("Not sent"), action: "Resend", onResend)
        case .submitted where batch.captures.count > 1:
            row(Text("Sent as one idea"))
        case .submitted, .unsendable:
            // A single capture's own row already says it all.
            EmptyView()
        }
    }

    private func row(
        _ title: Text,
        action: LocalizedStringKey? = nil,
        _ perform: @escaping () -> Void = {}
    ) -> some View {
        HStack {
            title
            Spacer(minLength: 8)
            if let action {
                // Borderless, or a tap anywhere in the header would count.
                Button(action, action: perform)
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        // Section headers can capitalize their text by default, and this one reads as a sentence.
        .textCase(nil)
    }
}
