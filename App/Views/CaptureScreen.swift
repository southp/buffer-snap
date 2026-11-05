import BufferSnapCore
import SwiftUI

/// The capture screen's container: owns `CaptureModel` and forwards typing, Save and the mic to it.
/// Everything it shows is drawn by the stateless `CaptureView`.
struct CaptureScreen: View {
    @State private var model: CaptureModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private let onShowCaptures: () -> Void

    init(store: any CaptureStore, speech: any SpeechTranscriber, onShowCaptures: @escaping () -> Void) {
        _model = State(initialValue: CaptureModel(store: store, speech: speech))
        self.onShowCaptures = onShowCaptures
    }

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
        #if DEBUG
            .safeAreaInset(edge: .bottom) {
                SpeechDiagnosticsView()
            }
        #endif
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
