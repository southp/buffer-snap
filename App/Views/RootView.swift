import BufferSnapCore
import SwiftUI

/// The top-level screen: shows whichever screen `AppModel.route` names.
struct RootView: View {
    let appModel: AppModel
    let environment: AppEnvironment

    var body: some View {
        switch appModel.route {
        case .signedOut:
            SignInView {
                Task {
                    await appModel.signIn()
                }
            }
        case .captures:
            CaptureListScreen(store: environment.captureStore)
        }
    }
}
