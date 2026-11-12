import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The account menu's items, rendered to AppTests/__Snapshots__/AccountMenuItemsTests/.
///
/// A snapshot can't open the toolbar's menu, so these lay its items out in an inset grouped `List`, one card per
/// section in the menu's order. They show which items and sections there are, with their labels and symbols. The PR
/// that changes the menu shows the real one in its screenshots.
@MainActor
struct AccountMenuItemsTests {
    /// Batching and How to Add Dictate an Idea, then Report a Problem and Source Code on GitHub, then Sign Out, then
    /// the version.
    @Test func signedIn() {
        assertScreenSnapshot(of: items(isSignedIn: true), named: "signedIn")
    }

    /// The same without Sign Out: there's no one to sign out.
    @Test func signedOut() {
        assertScreenSnapshot(of: items(isSignedIn: false), named: "signedOut")
    }

    private func items(isSignedIn: Bool) -> some View {
        List {
            AccountMenuItems(
                appVersion: AppVersion(version: "1.1", build: "42"),
                reportProblemURL: ProjectLinks.reportProblem,
                sourceCodeURL: ProjectLinks.sourceCode,
                isSignedIn: isSignedIn,
                onShowBatchingSettings: {},
                onShowAddDictationGuide: {},
                onSignOut: {}
            )
        }
        .listStyle(.insetGrouped)
        .tint(Theme.ink)
    }
}
