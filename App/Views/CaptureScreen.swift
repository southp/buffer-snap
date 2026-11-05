import BufferSnapCore
import SwiftUI

/// The capture screen's container: forwards typing and Save to `CaptureModel`.
/// Everything it shows is drawn by the stateless `CaptureView`.
///
/// Unlike other screens it doesn't own its model, as routing to sign-in destroys this screen and the draft has to
/// outlive that: `docs/decisions/44-draft-survives-session-end.md`.
struct CaptureScreen: View {
    let model: CaptureModel
    let onShowCaptures: () -> Void

    @Environment(\.scenePhase) private var scenePhase

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
