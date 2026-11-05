import BufferSnapCore
import SwiftUI

/// The capture screen's container: owns `CaptureModel` and forwards typing and Save to it.
/// Everything it shows is drawn by the stateless `CaptureView`.
struct CaptureScreen: View {
    @State private var model: CaptureModel
    @Environment(\.scenePhase) private var scenePhase

    private let onShowCaptures: () -> Void

    init(store: any CaptureStore, onShowCaptures: @escaping () -> Void) {
        _model = State(initialValue: CaptureModel(store: store))
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
            onSave: {
                Task {
                    await model.save()
                }
            },
            onShowCaptures: onShowCaptures
        )
        // The next time the app opens is for the next idea, so don't greet it with the last one's "Saved".
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.clearSaveResult()
            }
        }
    }
}
