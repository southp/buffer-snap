import BufferSnapCore
import SwiftUI

/// What the toolbar's `person` chip menu holds, one section per group, top to bottom:
/// 1. The account header: the name and email of who's signed in, not tappable. Only once Buffer has said who it is.
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
    /// Who's signed in, for the header, or `nil` while nobody is or Buffer hasn't said.
    let account: BufferAccount?
    /// Called when the user asks for the batching setting.
    let onShowBatchingSettings: () -> Void
    /// Called when the user asks how to add Dictate an Idea.
    let onShowAddDictationGuide: () -> Void
    /// Called when the user signs out.
    let onSignOut: () -> Void

    var body: some View {
        if isSignedIn, let account, account.displayName != nil || account.email != nil {
            Section {
                AccountHeader(name: account.displayName, email: account.email)
            }
        }
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

/// Who's signed in, at the top of the menu: the name, with the email under it. A disabled button, as that's what a
/// menu draws as a title over a subtitle: plain `Text`s would be two items, a `Label` or a stack drops the email.
/// Disabled, so it isn't tappable. The snapshot's list draws it less neatly than the menu does.
private struct AccountHeader: View {
    let name: String?
    let email: String?

    var body: some View {
        Button {
            // Disabled: there's nothing to do with it.
        } label: {
            if let name {
                Text(name)
            }
            if let email {
                Text(email)
            }
        }
        .disabled(true)
    }
}
