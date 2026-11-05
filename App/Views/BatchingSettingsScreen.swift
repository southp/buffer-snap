import BufferSnapCore
import SwiftUI

/// The batching setting's container: owns `BatchingSettingsModel` and forwards choices to it.
/// Everything it shows is drawn by the stateless `BatchingSettingsView`.
struct BatchingSettingsScreen: View {
    @State private var model: BatchingSettingsModel

    init(setting: any BatchWindowSetting, submissions: SubmissionQueue) {
        _model = State(initialValue: BatchingSettingsModel(setting: setting, submissions: submissions))
    }

    var body: some View {
        BatchingSettingsView(window: model.window, options: BatchWindow.options) { window in
            Task {
                await model.choose(window)
            }
        }
    }
}
