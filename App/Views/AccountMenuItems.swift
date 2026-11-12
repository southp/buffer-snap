import BufferSnapCore
import SwiftUI

/// What the toolbar's `person` chip menu holds, one section per group, top to bottom:
/// 1. The account header (#92 adds it here).
/// 2. Settings and guides: Batching, then How to Add Dictate an Idea, which opens the guide.
/// 3. Help: Report a Problem, which opens the support page's report section, and Source Code on GitHub.
/// 4. Sign Out, only while someone is signed in. In a menu, so one stray tap can't sign anyone out: coming back
///    takes a full sign-in.
/// 5. The version and build, not tappable, so people can quote it in a report.
///
/// Stateless: `CaptureListView` puts it in the menu, and a snapshot test can show it signed in and out.
struct AccountMenuItems: View {
    /// The version and build the last section shows.
    let appVersion: AppVersion
    /// Where Report a Problem goes: the support page's report section, which offers GitHub and email.
    let reportProblemURL: URL
    /// Where Source Code on GitHub goes.
    let sourceCodeURL: URL
    /// Whether to offer Sign Out.
    let isSignedIn: Bool
    /// Called when the user asks for the batching setting.
    let onShowBatchingSettings: () -> Void
    /// Called when the user asks how to add Dictate an Idea.
    let onShowAddDictationGuide: () -> Void
    /// Called when the user signs out.
    let onSignOut: () -> Void

    var body: some View {
        Section {
            Button("Batching", systemImage: "square.stack", action: onShowBatchingSettings)
            Button("How to Add Dictate an Idea", systemImage: "questionmark.circle", action: onShowAddDictationGuide)
        }
        Section {
            Link(destination: reportProblemURL) {
                Label("Report a Problem", systemImage: "exclamationmark.bubble")
            }
            Link(destination: sourceCodeURL) {
                Label("Source Code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
        if isSignedIn {
            Section {
                Button(
                    "Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive,
                    action: onSignOut)
            }
        }
        Section {
            Text("BufSnap \(appVersion.version) (\(appVersion.build))")
        }
    }
}
