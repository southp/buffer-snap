import BufferSnapCore
import SwiftUI

/// The capture screen: a large mic to hold and speak into, and the text box, its character count and Save as a backup.
///
/// Stateless: it renders what it's given and forwards actions, so snapshot tests can show any state. `CaptureScreen`
/// feeds it from `CaptureModel`.
struct CaptureView: View {
    /// The draft.
    @Binding var text: String
    /// How many characters the draft counts as.
    let characterCount: Int
    let characterLimit: Int
    let isOverLimit: Bool
    let canSave: Bool
    /// What the last save did, if the draft hasn't changed since.
    let saveResult: CaptureModel.SaveResult?
    /// How holding the mic is going.
    let dictation: CaptureModel.DictationState
    /// Called when the user taps Save.
    let onSave: () -> Void
    /// Called when a finger comes down on the mic.
    let onMicPress: () -> Void
    /// Called when the finger lifts, or the system takes the touch away.
    let onMicRelease: () -> Void
    /// Called when the user taps the button that opens Settings, shown when a permission is refused.
    let onOpenSettings: () -> Void
    /// Called when the user taps the button that opens the capture list.
    let onShowCaptures: () -> Void

    @FocusState private var isTyping: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("What's the idea?", text: $text, axis: .vertical)
                .lineLimit(10, reservesSpace: true)
                .focused($isTyping)
                .padding(12)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 12) {
                Text(verbatim: "\(characterCount)/\(characterLimit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(isOverLimit ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .accessibilityLabel("\(characterCount) of \(characterLimit) characters")
                CaptureSaveResultLabel(result: saveResult)
                Spacer(minLength: 0)
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            Spacer(minLength: 0)
            // There's no room for the mic above the keyboard. Done below hides the keyboard and brings it back.
            if !isTyping {
                DictationMessage(dictation: dictation, onOpenSettings: onOpenSettings)
                MicButton(dictation: dictation, onPress: onMicPress, onRelease: onMicRelease)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Captures", systemImage: "list.bullet", action: onShowCaptures)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTyping = false
                }
            }
        }
    }
}

/// What the last save did, or nothing before one.
private struct CaptureSaveResultLabel: View {
    let result: CaptureModel.SaveResult?

    var body: some View {
        switch result {
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .failed:
            Label("Couldn't save. Try again.", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}
