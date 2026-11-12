import BufferSnapCore
import SwiftUI

/// The capture list's container: owns `CaptureListModel`, loads it on appearing, on returning to the foreground and
/// when a send changes something, forwards deletes, resends, "Send now", Sync now and a confirmed Clear Submitted to
/// it, and passes sign-out up to whoever owns the session.
/// Everything it shows is drawn by the stateless `CaptureListView`.
struct CaptureListScreen: View {
    @State private var model: CaptureListModel
    @State private var isShowingBatchingSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private let submissions: SubmissionQueue
    private let batchWindow: any BatchWindowSetting
    /// What the sign-in row shows, or `nil` while someone is signed in.
    private let signInPrompt: AppModel.SignInPrompt?
    private let onSignIn: () -> Void
    private let onSignOut: () -> Void
    /// Read once: the bundle's version doesn't change while the app runs.
    private let appVersion = AppVersion(infoDictionary: Bundle.main.infoDictionary)
    /// What the permission row shows, or `nil` while there's nothing to fix.
    private let permissionNotice: DictationNotice?

    init(
        store: any CaptureStore,
        submissions: SubmissionQueue,
        batchWindow: any BatchWindowSetting,
        signInPrompt: AppModel.SignInPrompt?,
        onSignIn: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
        permissionNotice: DictationNotice?
    ) {
        _model = State(initialValue: CaptureListModel(store: store, submissions: submissions))
        self.submissions = submissions
        self.batchWindow = batchWindow
        self.signInPrompt = signInPrompt
        self.onSignIn = onSignIn
        self.onSignOut = onSignOut
        self.permissionNotice = permissionNotice
    }

    var body: some View {
        // Re-render every minute so "5 minutes ago" keeps up with the clock. Not `.everyMinute`: its entries are
        // dated on the minute boundary, up to 59 seconds behind the clock, so "5 minutes ago" would read "4".
        TimelineView(.periodic(from: .now, by: 60)) { context in
            CaptureListView(
                batches: model.batches,
                now: context.date,
                syncStatus: model.syncStatus(at: context.date),
                isSyncing: model.isSyncing,
                problem: model.problem,
                onSyncNow: {
                    Task {
                        await model.syncNow()
                    }
                },
                onDelete: { capture in
                    Task {
                        await model.delete(capture)
                    }
                },
                onSendNow: {
                    Task {
                        await model.sendNow()
                    }
                },
                onResend: { batch in
                    Task {
                        await model.resend(batch)
                    }
                },
                clearableIdeaCount: model.clearableIdeaCount,
                onClearSubmitted: {
                    Task {
                        await model.clearSubmitted()
                    }
                },
                onShowBatchingSettings: {
                    isShowingBatchingSettings = true
                },
                appVersion: appVersion,
                reportProblemURL: ProjectLinks.reportProblem,
                sourceCodeURL: ProjectLinks.sourceCode,
                signInPrompt: signInPrompt,
                onSignIn: onSignIn,
                onSignOut: onSignOut,
                permissionNotice: permissionNotice
            )
        }
        .navigationDestination(isPresented: $isShowingBatchingSettings) {
            BatchingSettingsScreen(setting: batchWindow, submissions: submissions)
        }
        .task {
            await model.loadAndFollowChanges()
        }
        // The widget writes to the store while the app is in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await model.load()
                }
            }
        }
    }
}
