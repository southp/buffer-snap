import BufferSnapCore
import SwiftUI

/// The top-level screen, and the only one: the capture list.
struct RootView: View {
    let appModel: AppModel
    let environment: AppEnvironment

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            CaptureListScreen(
                store: environment.captureStore,
                submissions: environment.submissions,
                batchWindow: environment.batchWindow,
                signInPrompt: appModel.signInPrompt,
                onSignIn: {
                    Task {
                        await appModel.signIn()
                    }
                },
                onSignOut: {
                    Task {
                        await appModel.signOut()
                    }
                }
            )
        }
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
        // A send found the session over: the list says so, the same way as coming to the foreground.
        .task {
            for await event in environment.submissions.events() where event == .sessionLost {
                await appModel.checkSession()
            }
        }
        .alert(ideasQuestion, isPresented: isAskingAboutIdeas) {
            Button("Send") {
                Task {
                    await appModel.sendHeldIdeas()
                }
            }
            Button("Not Now", role: .cancel, action: appModel.keepHeldIdeas)
        } message: {
            Text(
                """
                You saved them before signing in. If you choose Not Now, they stay on this iPhone, with Resend on each.
                """
            )
        }
    }

    /// Answered only through the alert's buttons, which clear it.
    private var isAskingAboutIdeas: Binding<Bool> {
        Binding(get: { appModel.ideasToConfirm != nil }, set: { _ in })
    }

    private var ideasQuestion: Text {
        let count = appModel.ideasToConfirm ?? 0
        return count == 1 ? Text("Send 1 idea to this account?") : Text("Send \(count) ideas to this account?")
    }
}
