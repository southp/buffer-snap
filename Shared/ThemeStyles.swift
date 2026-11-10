import SwiftUI

// MARK: - Cards

/// Which part of a card a list row draws. A `List` gives each row its own background, so a card of several rows is
/// drawn a part per row: the top one has the top corners, the bottom one the bottom corners and the shadow below.
enum CardPart: Equatable {
    case whole
    case top
    case middle
    case bottom

    /// The part of the row at `index` in a card of `count` rows.
    init(index: Int, count: Int) {
        switch (index == 0, index == count - 1) {
        case (true, true):
            self = .whole
        case (true, false):
            self = .top
        case (false, true):
            self = .bottom
        case (false, false):
            self = .middle
        }
    }

    /// Whether the card goes on above this row.
    var continuesAbove: Bool {
        self == .middle || self == .bottom
    }

    /// Whether the card goes on below this row.
    var continuesBelow: Bool {
        self == .top || self == .middle
    }
}

/// A card, or a row's part of one: white, with an ink outline and an ink shadow offset right and down, with no blur.
/// It leaves `Theme.cardMargin` on each side, and room below for the shadow where the card ends.
struct CardBackground: View {
    var part: CardPart = .whole

    /// How far an open edge reaches past the row, so its outline and shadow are cut off rather than drawn.
    private let overhang: CGFloat = 6

    var body: some View {
        // Clear takes the row's size, and `clipped()` cuts what the card draws past it.
        Color.clear
            .overlay {
                OutlinedShape(
                    shape: UnevenRoundedRectangle(cornerRadii: radii, style: .continuous),
                    shadow: Theme.cardShadow
                )
                .padding(.horizontal, Theme.cardMargin)
                .padding(.top, part.continuesAbove ? -overhang : 0)
                .padding(.bottom, part.continuesBelow ? -overhang : Theme.cardShadow)
            }
            .overlay(alignment: .top) {
                if part.continuesAbove {
                    Theme.divider
                        .frame(height: 1)
                        .padding(.horizontal, Theme.cardMargin + Theme.cardPadding)
                }
            }
            .clipped()
    }

    private var radii: RectangleCornerRadii {
        let top = part.continuesAbove ? 0 : Theme.cornerRadius
        let bottom = part.continuesBelow ? 0 : Theme.cornerRadius
        return RectangleCornerRadii(
            topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top
        )
    }
}

extension View {
    /// Draws this list row as `part` of a card: inside its outline, with the List's own separator and background off.
    func cardRow(_ part: CardPart = .whole, verticalPadding: CGFloat = 12) -> some View {
        let inset = Theme.cardMargin + Theme.cardPadding
        return
            self
            .padding(.top, verticalPadding)
            .padding(.bottom, verticalPadding + (part.continuesBelow ? 0 : Theme.cardShadow))
            .listRowInsets(EdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset))
            .listRowBackground(CardBackground(part: part))
            .listRowSeparator(.hidden)
    }

    /// The paper behind a whole screen, in place of the system's grouped background.
    func paperBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
    }
}

// MARK: - Buttons

/// A capsule with an ink outline: Tomato for the main action, white for the others, and white with a small offset
/// shadow for a chip, such as a toolbar's, or a round one around an icon. Text on Tomato is ink, never white.
///
/// Capsules are `.circular`: on iOS 27, a `.continuous` capsule's outline drew stray bars beside its ends.
struct PaperInkButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case chip
        case iconChip
    }

    var kind: Kind = .secondary

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var iconChipDiameter: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        styled(configuration.label)
            .foregroundStyle(kind == .primary ? Theme.onColor : Theme.ink)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }

    @ViewBuilder
    private func styled(_ label: Configuration.Label) -> some View {
        switch kind {
        case .iconChip:
            label
                .font(.inter(.body, weight: .semibold))
                .frame(width: iconChipDiameter, height: iconChipDiameter)
                .background {
                    OutlinedShape(shape: Circle(), shadow: Theme.chipShadow)
                }
        case .primary, .secondary, .chip:
            label
                .font(.inter(kind == .primary ? .body : .subheadline, weight: .bold))
                .padding(.horizontal, kind == .primary ? 16 : 12)
                .padding(.vertical, kind == .primary ? 12 : 7)
                .background {
                    OutlinedShape(
                        shape: Capsule(style: .circular),
                        fill: kind == .primary ? Theme.tomato : Theme.surface,
                        shadow: kind == .chip ? Theme.chipShadow : 0
                    )
                }
        }
    }
}

extension ButtonStyle where Self == PaperInkButtonStyle {
    /// The main action: Tomato, with ink text.
    static var paperInkPrimary: PaperInkButtonStyle {
        PaperInkButtonStyle(kind: .primary)
    }

    /// Any other action: white, with ink text.
    static var paperInkSecondary: PaperInkButtonStyle {
        PaperInkButtonStyle(kind: .secondary)
    }

    /// A chip, such as a toolbar's: white, with a small offset shadow.
    static var paperInkChip: PaperInkButtonStyle {
        PaperInkButtonStyle(kind: .chip)
    }

    /// A round chip around an icon.
    static var paperInkIconChip: PaperInkButtonStyle {
        PaperInkButtonStyle(kind: .iconChip)
    }
}

/// A shape filled with `fill`, with an ink outline and, if `shadow` isn't zero, an ink shadow that far right and down.
/// On something that stays light in dark mode, such as the widget's Sun, pass `Theme.onColor` as `ink`.
struct OutlinedShape<S: InsettableShape>: View {
    let shape: S
    var fill: Color = Theme.surface
    var ink: Color = Theme.ink
    var lineWidth: CGFloat = Theme.borderWidth
    var shadow: CGFloat = 0

    var body: some View {
        ZStack {
            if shadow > 0 {
                shape
                    .fill(ink)
                    .offset(x: shadow, y: shadow)
            }
            shape.fill(fill)
            shape.strokeBorder(ink, lineWidth: lineWidth)
        }
    }
}

// MARK: - Pills and badges

/// A status as a capsule: ink text on `fill`, with a thin ink outline.
struct Pill: View {
    let text: Text
    let fill: Color

    var body: some View {
        text
            .font(.inter(.caption, weight: .bold))
            .foregroundStyle(Theme.onColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                OutlinedShape(shape: Capsule(style: .circular), fill: fill, lineWidth: Theme.pillBorderWidth)
            }
    }
}

/// A symbol in a filled circle with a thin ink outline, such as a step's number or a status's icon.
struct Badge<Content: View>: View {
    var fill: Color = Theme.sun
    var diameter: CGFloat = 30
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        content
            .foregroundStyle(Theme.onColor)
            .frame(width: diameter * scale, height: diameter * scale)
            .background(fill, in: Circle())
            .overlay {
                Circle().strokeBorder(Theme.ink, lineWidth: Theme.pillBorderWidth)
            }
    }
}
