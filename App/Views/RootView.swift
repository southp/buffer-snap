import BufferSnapCore
import SwiftUI

/// The top-level screen: shows whichever screen `AppModel.route` names.
///
/// The capture list is pushed on top of the capture screen, so a draft survives a look at the list. The route still
/// decides: the stack only reports back when the user goes back.
struct RootView: View {
    let appModel: AppModel
    let environment: AppEnvironment

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        screen
            // Refreshes a token that's due, and finds out if Buffer has ended the session.
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    Task {
                        await appModel.checkSession()
                    }
                }
            }
    }

    @ViewBuilder
    private var screen: some View {
        switch appModel.route {
        case .signedOut:
            SignInView(notice: appModel.signInNotice, isSigningIn: appModel.isSigningIn) {
                Task {
                    await appModel.signIn()
                }
            }
        case .capture, .captureList:
            NavigationStack {
                CaptureScreen(
                    store: environment.captureStore,
                    speech: environment.speech,
                    onShowCaptures: appModel.showCaptureList
                )
                .navigationDestination(isPresented: isShowingCaptureList) {
                    CaptureListScreen(store: environment.captureStore) {
                        Task {
                            await appModel.signOut()
                        }
                    }
                }
            }
        }
    }

    private var isShowingCaptureList: Binding<Bool> {
        Binding(
            get: { appModel.route == .captureList },
            set: { isShowing in
                if !isShowing {
                    appModel.showCapture()
                }
            }
        )
    }
}
