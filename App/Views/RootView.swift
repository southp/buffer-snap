import BufferSnapCore
import SwiftUI

/// The top-level screen: shows whichever screen `AppModel.route` names.
///
/// The capture list is pushed on top of the capture screen, so a draft survives a look at the list. The route still
/// decides: the stack only reports back when the user goes back.
struct RootView: View {
    let appModel: AppModel
    let captureModel: CaptureModel
    let environment: AppEnvironment

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        screen
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active:
                    // Refreshes a token that's due, and finds out if Buffer has ended the session.
                    Task {
                        await appModel.checkSession()
                    }
                    Task {
                        await environment.submissions.run()
                    }
                case .background:
                    BackgroundSubmission.scheduleWakeUp()
                    BackgroundSubmission.finishSending(on: environment.submissions)
                default:
                    break
                }
            }
            .task {
                await environment.submissions.runOnEachReconnection(of: environment.connectivity)
            }
            // A send found the session over: the route goes to sign-in the same way as coming to the foreground.
            .task {
                for await event in environment.submissions.events() where event == .sessionLost {
                    await appModel.checkSession()
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
                CaptureScreen(model: captureModel, onShowCaptures: appModel.showCaptureList)
                    .navigationDestination(isPresented: isShowingCaptureList) {
                        CaptureListScreen(store: environment.captureStore, submissions: environment.submissions) {
                            captureModel.discardDraft()
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
