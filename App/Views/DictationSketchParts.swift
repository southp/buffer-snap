import SwiftUI

// The parts `DictationStepSketch` draws its sketches from, in a phone's coordinates (50 × 82 points, origin at the top
// left). Only the sketches use them.

/// Sizes every sketch shares. A sketch is a fixed drawing: it doesn't grow with Dynamic Type, the step's text does.
enum SketchMetrics {
    /// The square each sketch is drawn in.
    static let canvas: CGFloat = 88
    /// The outlines of the phone and of what's in it.
    static let line: CGFloat = 1.5
}

/// A phone, front on, in ink outline, with what's on its screen drawn by `content` in its own coordinates
/// (`width` × `height`, origin at the top left). With `sideButton`, the Action button on its left side is Tomato.
struct SketchPhone<Content: View>: View {
    var width: CGFloat = 50
    var height: CGFloat = 82
    var fill: Color = Theme.surface
    var sideButton = false
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
        ZStack(alignment: .topLeading) {
            Color.clear
            content
        }
        .frame(width: width, height: height)
        .background(fill)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Theme.ink, lineWidth: Theme.borderWidth)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Theme.ink)
                .frame(width: width * 0.3, height: 4)
                .padding(.top, 4)
        }
        .overlay(alignment: .topLeading) {
            if sideButton {
                Capsule()
                    .fill(Theme.tomato)
                    .overlay {
                        Capsule().strokeBorder(Theme.ink, lineWidth: 1)
                    }
                    .frame(width: 4, height: 11)
                    .offset(x: -3, y: 16)
            }
        }
        .background {
            shape
                .fill(Theme.ink)
                .offset(x: Theme.chipShadow, y: Theme.chipShadow)
        }
    }
}

/// Where to touch: a Tomato dot. Held, it has a ring around it.
struct SketchTouch: View {
    var isHeld = false

    var body: some View {
        ZStack {
            if isHeld {
                Circle()
                    .strokeBorder(Theme.tomato, lineWidth: SketchMetrics.line)
                    .frame(width: 26, height: 26)
                    .opacity(0.6)
            }
            Circle()
                .fill(Theme.tomato.opacity(0.45))
                .overlay {
                    Circle().strokeBorder(Theme.tomato, lineWidth: SketchMetrics.line)
                }
                .frame(width: 15, height: 15)
        }
    }
}

/// Which way to swipe.
struct SketchArrow: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(Theme.tomatoText)
    }
}

/// The Dictate an Idea control: BufSnap's symbol in a Tomato circle, as on the widget.
struct SketchBulb: View {
    let diameter: CGFloat

    var body: some View {
        Image(decorative: "bufsnap.dictate")
            .font(.system(size: diameter * 0.5, weight: .bold))
            .foregroundStyle(Theme.onColor)
            .frame(width: diameter, height: diameter)
            .background {
                OutlinedShape(shape: Circle(), fill: Theme.tomato, lineWidth: SketchMetrics.line)
            }
    }
}

/// A round button with a symbol, such as Control Center's +.
struct SketchRoundButton: View {
    let systemName: String
    var diameter: CGFloat = 14
    var fill: Color = Theme.surface

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: diameter * 0.55, weight: .heavy))
            .foregroundStyle(fill == Theme.surface ? Theme.ink : Theme.onColor)
            .frame(width: diameter, height: diameter)
            .background {
                OutlinedShape(shape: Circle(), fill: fill, lineWidth: SketchMetrics.line)
            }
    }
}

/// An empty round control, such as a Lock Screen button.
struct SketchCircle: View {
    let diameter: CGFloat

    var body: some View {
        OutlinedShape(shape: Circle(), fill: Theme.divider, lineWidth: SketchMetrics.line)
            .frame(width: diameter, height: diameter)
    }
}

/// A button, as a capsule with a line for its label and, if given, a symbol before it.
struct SketchPill: View {
    let width: CGFloat
    var height: CGFloat = 12
    var systemName: String?
    var fill: Color = Theme.surface

    var body: some View {
        HStack(spacing: 3) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: height * 0.55, weight: .heavy))
            }
            Capsule()
                .frame(height: 2.5)
        }
        .foregroundStyle(fill == Theme.surface ? Theme.ink : Theme.onColor)
        .padding(.horizontal, height * 0.45)
        .frame(width: width, height: height)
        .background {
            OutlinedShape(shape: Capsule(style: .circular), fill: fill, lineWidth: SketchMetrics.line)
        }
    }
}

/// A search field.
struct SketchSearchField: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 6, weight: .heavy))
            Capsule()
                .frame(width: 16, height: 2.5)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 5)
        .frame(width: 40, height: 11)
        .background {
            OutlinedShape(shape: Capsule(style: .circular), fill: Theme.paper, lineWidth: 1)
        }
    }
}

/// A grid of rounded squares, centered across the phone from `top` down: Control Center's controls or the Home
/// Screen's apps.
struct SketchTiles: View {
    let rows: Int
    let top: CGFloat
    var columns = 2
    var size: CGFloat = 14
    var spacing: CGFloat = 6

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { _ in
                        OutlinedShape(
                            shape: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous),
                            fill: Theme.divider,
                            lineWidth: SketchMetrics.line
                        )
                        .frame(width: size, height: size)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, top)
    }
}

/// A Lock Screen: the date, the time and, unless they're drawn separately, the two buttons at the bottom. Drawn for
/// the full-size phone, then scaled.
struct SketchLockScreen: View {
    var scale: CGFloat = 1
    var ink: Color = Theme.ink
    var showsBottomButtons = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Capsule()
                .fill(ink.opacity(0.5))
                .frame(width: 16, height: 3)
                .position(x: 25, y: 14)
            Capsule()
                .fill(ink)
                .frame(width: 28, height: 9)
                .position(x: 25, y: 23)
            if showsBottomButtons {
                ForEach([13, 37], id: \.self) { centerX in
                    Circle()
                        .strokeBorder(ink, lineWidth: SketchMetrics.line)
                        .frame(width: 11, height: 11)
                        .position(x: CGFloat(centerX), y: 67)
                }
            }
        }
        .frame(width: 50, height: 82)
        .scaleEffect(scale, anchor: .topLeading)
        // Scaling only draws smaller: the frame says how much room it takes.
        .frame(width: 50 * scale, height: 82 * scale, alignment: .topLeading)
    }
}

/// Settings rows, as an icon and a line each, from `top` down. The `highlighted` one is Sun, with, if
/// `showsAppIcon`, BufSnap's bulb as its icon.
struct SketchListRows: View {
    var top: CGFloat = 24
    let highlighted: Int
    var showsAppIcon = false

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                let isHighlighted = index == highlighted
                HStack(spacing: 4) {
                    icon(isHighlighted: isHighlighted)
                    Capsule()
                        .fill(isHighlighted ? Theme.onColor : Theme.muted)
                        .frame(height: 2.5)
                }
                .padding(.horizontal, 4)
                .frame(width: 42, height: 12)
                .background {
                    if isHighlighted {
                        OutlinedShape(
                            shape: RoundedRectangle(cornerRadius: 4, style: .continuous),
                            fill: Theme.sun,
                            lineWidth: 1
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, top - 6)
    }

    @ViewBuilder private func icon(isHighlighted: Bool) -> some View {
        if showsAppIcon && isHighlighted {
            Image(decorative: "bufsnap.dictate")
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(Theme.onColor)
                .frame(width: 8, height: 8)
                .background(Theme.tomato, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isHighlighted ? Theme.onColor : Theme.muted)
                .frame(width: 7, height: 7)
        }
    }
}

/// The Action button's settings: one action per page, with Controls in the middle, Sun, and the pages beside it
/// peeking in from the edges.
struct SketchCarousel: View {
    var top: CGFloat = 18

    var body: some View {
        HStack(spacing: 6) {
            page(fill: Theme.divider)
            Image(systemName: "switch.2")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.onColor)
                .frame(width: 26, height: 36)
                .background {
                    OutlinedShape(
                        shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                        fill: Theme.sun,
                        lineWidth: SketchMetrics.line
                    )
                }
            page(fill: Theme.divider)
        }
        .frame(width: 50)
        .padding(.top, top)
    }

    private func page(fill: Color) -> some View {
        OutlinedShape(
            shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
            fill: fill,
            lineWidth: SketchMetrics.line
        )
        .frame(width: 26, height: 30)
    }
}

/// The Dictate an Idea widget, as `DictateWidgetView` draws it: the bulb in a Tomato circle on Sun.
struct SketchWidget: View {
    var body: some View {
        SketchBulb(diameter: 18)
            .frame(width: 32, height: 32)
            .background {
                OutlinedShape(
                    shape: RoundedRectangle(cornerRadius: 8, style: .continuous),
                    fill: Theme.sun,
                    ink: Theme.onColor,
                    lineWidth: SketchMetrics.line
                )
            }
    }
}
