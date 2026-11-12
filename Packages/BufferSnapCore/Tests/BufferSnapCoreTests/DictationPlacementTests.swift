import BufferSnapCore
import Foundation
import Testing

/// The guide's placements and their steps. The step texts are also the support page's, word for word
/// (`site/support/index.html`), so a change here goes there too.
struct DictationPlacementTests {
    /// All four, always, in the guide's order: none is hidden on iPhones without it.
    @Test func everyPlacementShowsInOrder() {
        #expect(DictationPlacement.allCases == [.controlCenter, .lockScreen, .actionButton, .homeScreen])
        #expect(
            DictationPlacement.allCases.map { String(localized: $0.title) } == [
                "Control Center", "Lock Screen", "Action Button", "Home Screen",
            ])
    }

    /// Only the Action button says which iPhones have it, and it says so without asking which iPhone this is.
    @Test func onlyTheActionButtonNamesTheIPhonesThatHaveIt() {
        let requirements = DictationPlacement.allCases.map { $0.requirement.map { String(localized: $0) } }

        #expect(requirements == [nil, nil, "iPhone 15 Pro and later", nil])
    }

    @Test func controlCenterSteps() {
        #expect(
            texts(of: .controlCenter) == [
                "Swipe down from the top-right corner.",
                "Tap + at the top left.",
                "Tap Add a Control.",
                "Search for “Dictate an Idea” and tap it.",
            ])
        #expect(
            sketches(of: .controlCenter) == [
                .swipeDownFromTopRight, .tapPlusAtTopLeft, .tapAddAControl, .searchForTheControl,
            ])
    }

    @Test func lockScreenSteps() {
        #expect(
            texts(of: .lockScreen) == [
                "Touch and hold the Lock Screen.",
                "Tap Customize, then Lock Screen.",
                "Tap − on one of the bottom buttons.",
                "Tap + in its place and choose Dictate an Idea.",
            ])
        #expect(
            sketches(of: .lockScreen) == [
                .touchAndHoldLockScreen, .tapCustomizeThenLockScreen, .removeABottomButton, .addABottomButton,
            ])
    }

    @Test func actionButtonSteps() {
        #expect(
            texts(of: .actionButton) == [
                "Open Settings and tap Action Button.",
                "Swipe to Controls.",
                "Tap Choose a Control.",
                "Search for “Dictate an Idea” and tap it.",
            ])
        #expect(
            sketches(of: .actionButton) == [
                .openActionButtonSettings, .swipeToControls, .tapChooseAControl, .searchForTheControl,
            ])
    }

    @Test func homeScreenSteps() {
        #expect(
            texts(of: .homeScreen) == [
                "Touch and hold an empty spot on the Home Screen.",
                "Tap Edit, then Add Widget.",
                "Search for BufSnap and tap it.",
                "Tap Add Widget under Dictate an Idea.",
            ])
        #expect(
            sketches(of: .homeScreen) == [
                .touchAndHoldHomeScreen, .tapEditThenAddWidget, .chooseBufSnap, .addTheWidget,
            ])
    }

    /// Every sketch is drawn for some step, so none is left behind when a step changes.
    @Test func everySketchIsUsed() {
        let used = Set(DictationPlacement.allCases.flatMap { sketches(of: $0) })

        #expect(used == Set(DictationPlacementStep.Sketch.allCases))
    }

    private func texts(of placement: DictationPlacement) -> [String] {
        placement.steps.map { String(localized: $0.text) }
    }

    private func sketches(of placement: DictationPlacement) -> [DictationPlacementStep.Sketch] {
        placement.steps.map(\.sketch)
    }
}
