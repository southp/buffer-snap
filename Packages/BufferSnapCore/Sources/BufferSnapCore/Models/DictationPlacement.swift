import Foundation

/// Where someone can put Dictate an Idea, so one press dictates without opening BufSnap, and the steps that put it
/// there. The How to Add guide shows every one, in this order. iOS has no API that adds a control for an app
/// (`docs/decisions/98-show-how-to-add-the-control.md`), so the guide shows the steps instead.
///
/// The Action button's steps are always offered, labeled with the iPhones that have one, rather than hidden on the
/// others: telling models apart would go out of date with every new iPhone.
///
/// The step texts match the support page's "Dictating without opening the app" word for word
/// (`site/support/index.html`). Change both together.
public enum DictationPlacement: CaseIterable, Hashable, Identifiable, Sendable {
    case controlCenter
    case lockScreen
    case actionButton
    case homeScreen

    public var id: Self {
        self
    }

    /// The placement's name, as the guide's picker shows it.
    public var title: LocalizedStringResource {
        switch self {
        case .controlCenter:
            "Control Center"
        case .lockScreen:
            "Lock Screen"
        case .actionButton:
            "Action Button"
        case .homeScreen:
            "Home Screen"
        }
    }

    /// Which iPhones have it, when not all of them do.
    public var requirement: LocalizedStringResource? {
        switch self {
        case .actionButton:
            "iPhone 15 Pro and later"
        case .controlCenter, .lockScreen, .homeScreen:
            nil
        }
    }

    /// What to do, in order. The guide numbers them from 1.
    public var steps: [DictationPlacementStep] {
        switch self {
        case .controlCenter:
            [
                DictationPlacementStep("Swipe down from the top-right corner.", sketch: .swipeDownFromTopRight),
                DictationPlacementStep("Tap + at the top left.", sketch: .tapPlusAtTopLeft),
                DictationPlacementStep("Tap Add a Control.", sketch: .tapAddAControl),
                DictationPlacementStep("Search for “Dictate an Idea” and tap it.", sketch: .searchForTheControl),
            ]
        case .lockScreen:
            [
                DictationPlacementStep("Touch and hold the Lock Screen.", sketch: .touchAndHoldLockScreen),
                DictationPlacementStep("Tap Customize, then Lock Screen.", sketch: .tapCustomizeThenLockScreen),
                DictationPlacementStep("Tap − on one of the bottom buttons.", sketch: .removeABottomButton),
                DictationPlacementStep("Tap + in its place and choose Dictate an Idea.", sketch: .addABottomButton),
            ]
        case .actionButton:
            [
                DictationPlacementStep("Open Settings and tap Action Button.", sketch: .openActionButtonSettings),
                DictationPlacementStep("Swipe to Controls.", sketch: .swipeToControls),
                DictationPlacementStep("Tap Choose a Control.", sketch: .tapChooseAControl),
                DictationPlacementStep("Search for “Dictate an Idea” and tap it.", sketch: .searchForTheControl),
            ]
        case .homeScreen:
            [
                DictationPlacementStep(
                    "Touch and hold an empty spot on the Home Screen.", sketch: .touchAndHoldHomeScreen),
                DictationPlacementStep("Tap Edit, then Add Widget.", sketch: .tapEditThenAddWidget),
                DictationPlacementStep("Search for BufSnap and tap it.", sketch: .chooseBufSnap),
                DictationPlacementStep("Tap Add Widget under Dictate an Idea.", sketch: .addTheWidget),
            ]
        }
    }
}

/// One step of putting Dictate an Idea somewhere: what to do, and which sketch shows it.
public struct DictationPlacementStep: Sendable {
    /// What to do, as one sentence. VoiceOver reads this; the sketch is decoration.
    public let text: LocalizedStringResource
    /// The drawing beside it.
    public let sketch: Sketch

    init(_ text: LocalizedStringResource, sketch: Sketch) {
        self.text = text
        self.sketch = sketch
    }

    /// A still Paper & Ink drawing of a step, which the app draws in SwiftUI rather than showing a screenshot: a
    /// screenshot would show iOS's own UI in one language and one version. Named after what it shows.
    public enum Sketch: CaseIterable, Hashable, Sendable {
        case swipeDownFromTopRight
        case tapPlusAtTopLeft
        case tapAddAControl
        /// Control Center and the Action button end the same way.
        case searchForTheControl
        case touchAndHoldLockScreen
        case tapCustomizeThenLockScreen
        case removeABottomButton
        case addABottomButton
        case openActionButtonSettings
        case swipeToControls
        case tapChooseAControl
        case touchAndHoldHomeScreen
        case tapEditThenAddWidget
        case chooseBufSnap
        case addTheWidget
    }
}
