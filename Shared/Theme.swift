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

    /// Caveat Bold. Only `View.caveat(_:)` sets it, since text in Caveat needs room to draw past its frame.
    /// `.weight(.bold)` picks the font's own Bold instance (wght 700), not a synthesized one.
    fileprivate static func caveat(_ style: Font.TextStyle) -> Font {
        .custom("Caveat", size: style.caveatSize, relativeTo: style).weight(.bold)
    }
}

extension View {
    /// Sets text in Caveat Bold, the handwritten face, for large titles and big headings only. Grows with Dynamic Type
    /// like `style`.
    ///
    /// Caveat's letters reach past their advance width (the last "s" of "Captures" by 0.09 em), and SwiftUI clips a
    /// `Text`'s drawing at its frame, which cut that "s" off (#97). So this also lets the text draw past its frame on
    /// both sides, without changing its layout.
    func caveat(_ style: Font.TextStyle) -> some View {
        modifier(CaveatText(style: style))
    }
}

/// Caveat, with room to draw its overhang.
private struct CaveatText: ViewModifier {
    /// How far any of Caveat Bold's glyphs reaches past its advance width, in ems: its widest is the fraction slash's
    /// 0.326 em on the trailing side. Measured from `Shared/Fonts/Caveat.ttf` at wght 700 with fontTools.
    private static let overhangInEms: CGFloat = 1.0 / 3.0

    let style: Font.TextStyle
    /// The overhang at this style's size, scaled with Dynamic Type like the font.
    @ScaledMetric private var overhang: CGFloat

    init(style: Font.TextStyle) {
        self.style = style
        _overhang = ScaledMetric(wrappedValue: style.caveatSize * Self.overhangInEms, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content
            .font(.caveat(style))
            .textRenderer(OverhangingText(overhang: overhang))
    }
}

/// Draws text as SwiftUI would, but may draw `overhang` past the text's leading and trailing edges.
private struct OverhangingText: TextRenderer {
    let overhang: CGFloat

    var displayPadding: EdgeInsets {
        EdgeInsets(top: 0, leading: overhang, bottom: 0, trailing: overhang)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            context.draw(line)
        }
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
