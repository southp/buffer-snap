import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The How to Add guide, one place picked per test, rendered full-screen to
/// AppTests/__Snapshots__/AddDictationGuideViewTests/: light, dark, and at xxxLarge, where the steps grow and the
/// picker's names wrap.
///
/// Wrapped in a `NavigationStack`, as `AddDictationGuideScreen` shows it, so Done renders.
@MainActor
struct AddDictationGuideViewTests {
    @Test func controlCenter() {
        assertGuide(showing: .controlCenter, named: "controlCenter")
    }

    @Test func lockScreen() {
        assertGuide(showing: .lockScreen, named: "lockScreen")
    }

    /// The only place that names the iPhones that have it.
    @Test func actionButton() {
        assertGuide(showing: .actionButton, named: "actionButton")
    }

    @Test func homeScreen() {
        assertGuide(showing: .homeScreen, named: "homeScreen")
    }

    private func assertGuide(
        showing placement: DictationPlacement,
        named name: String,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertScreenSnapshot(of: guide(placement), named: name, filePath: filePath, testName: testName, line: line)
        assertScreenSnapshot(
            of: guide(placement), named: "\(name)-dark", appearance: .dark, filePath: filePath, testName: testName,
            line: line)
        assertScreenSnapshot(
            of: guide(placement).dynamicTypeSize(.xxxLarge), named: "\(name)-xxxLarge", filePath: filePath,
            testName: testName, line: line)
    }

    private func guide(_ placement: DictationPlacement) -> some View {
        NavigationStack {
            AddDictationGuideView(placement: placement, onChoose: { _ in }, onDone: {})
        }
        .tint(Theme.ink)
    }
}
