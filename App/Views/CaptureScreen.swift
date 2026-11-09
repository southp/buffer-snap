import BufferSnapCore
import SwiftUI

/// The capture screen's container: forwards typing, Save and the mic to `CaptureModel`.
/// Everything it shows is drawn by the stateless `CaptureView`.
///
/// Unlike other screens it doesn't own its model, so a draft can outlive this screen, for one thing across a session
/// Buffer ended: `docs/decisions/44-draft-survives-session-end.md`.
struct CaptureScreen: View {
    let model: CaptureModel
    let onShowCaptures: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        CaptureView(
            text: Binding(
                get: { model.text },
                set: { model.update(text: $0) }
            ),
            characterCount: model.characterCount,
            characterLimit: CaptureModel.characterLimit,
            isOverLimit: model.isOverLimit,
            canSave: model.canSave,
            saveResult: model.saveResult,
            dictation: model.dictation,
            onSave: {
                Task {
                    await model.save()
                }
            },
            onMicPress: {
                Task {
                    await model.startDictation()
                }
            },
            onMicRelease: {
                Task {
                    await model.finishDictation()
                }
            },
            onOpenSettings: {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            },
            onShowCaptures: onShowCaptures
        )
        .task {
            await model.refreshDictationPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // The user may be back from turning a permission on or off in Settings.
                Task {
                    await model.refreshDictationPermission()
                }
            case .background:
                // The next time the app opens is for the next idea, so don't greet it with the last one's "Saved".
                model.clearSaveResult()
                Task {
                    await model.interruptDictation()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
