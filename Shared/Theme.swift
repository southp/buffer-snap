import SwiftUI

/// Paper & Ink: sketchbook paper, bold ink outlines, a tomato accent and a handwritten title
/// (`docs/decisions/84-paper-and-ink.md`). Views take their colors, fonts and shapes from here, never hard-coded.
///
/// In `Shared/`, so the app and the widget extension draw from the same tokens. Each color is a color set in
/// `Shared/Theme.xcassets` with a light and a dark value, which WidgetKit resolves for the Lock Screen and the Home
/// Screen as reliably as the app does.
enum Theme {
    // MARK: Colors

    /// The screen's background.
    static let paper = Color("Paper")
    /// Cards and chips.
    static let surface = Color("Surface")
    /// Text, outlines and offset shadows. Cream in dark mode.
    static let ink = Color("Ink")
    /// Secondary text.
    static let muted = Color("Muted")
    /// Lines inside a card.
    static let divider = Color("Divider")
    /// Primary buttons, Stop and the accent. Put `onColor` text on it, never white.
    static let tomato = Color("Tomato")
    /// The accent as text on paper or a card, such as "Send now".
    static let tomatoText = Color("TomatoText")
    /// The pending pill, the widget's background and step badges.
    static let sun = Color("Sun")
    /// The submitted pill.
    static let mint = Color("Mint")
    /// "Saved" in the Live Activity.
    static let saved = Color("Saved")
    /// Text and glyphs on Tomato, Sun or Mint, which stay the same in dark mode, so this stays ink.
    static let onColor = Color("OnColor")

    // MARK: Shapes

    /// A card's corners.
    static let cornerRadius: CGFloat = 14
    /// A card's or a button's outline.
    static let borderWidth: CGFloat = 2
    /// A pill's outline.
    static let pillBorderWidth: CGFloat = 1.5
    /// How far a card's shadow sits right and down. It has no blur.
    static let cardShadow: CGFloat = 3
    /// How far a chip's shadow sits right and down.
    static let chipShadow: CGFloat = 2
    /// How far a card sits from the screen's edges.
    static let cardMargin: CGFloat = 16
    /// How far a card's content sits from its edges.
    static let cardPadding: CGFloat = 14
}

// MARK: - Fonts

extension Font {
    /// Inter, for everything but large titles. Grows with Dynamic Type like `style`.
    static func inter(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: style.paperInkSize, relativeTo: style).weight(weight)
    }

    /// Caveat Bold, the handwritten face, for large titles and big headings only. Grows with Dynamic Type like `style`.
    static func caveat(_ style: Font.TextStyle) -> Font {
        .custom("Caveat", size: style.caveatSize, relativeTo: style).weight(.bold)
    }
}

extension Font.TextStyle {
    /// The system's size for this style at the default text size, which Inter matches.
    fileprivate var paperInkSize: CGFloat {
        switch self {
        case .largeTitle:
            34
        case .title:
            28
        case .title2:
            22
        case .title3:
            20
        case .headline, .body:
            17
        case .callout:
            16
        case .subheadline:
            15
        case .footnote:
            13
        case .caption:
            12
        case .caption2:
            11
        @unknown default:
            17
        }
    }

    /// Caveat's letters are small for their size, so it's set larger than Inter for the same style.
    fileprivate var caveatSize: CGFloat {
        paperInkSize * 1.25
    }
}
