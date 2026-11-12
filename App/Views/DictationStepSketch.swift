import BufferSnapCore
import SwiftUI

/// A still Paper & Ink drawing of one step of adding Dictate an Idea: a phone in ink outline, the part to touch in
/// Tomato, and the control as BufSnap's own symbol (`bufsnap.dictate`). It hints at iOS's screens rather than copying
/// them, so it holds no text to translate and doesn't go out of date with each iOS.
///
/// Decorative: the step's text says what to do, so VoiceOver skips the drawing.
struct DictationStepSketch: View {
    let sketch: DictationPlacementStep.Sketch

    var body: some View {
        drawing
            .frame(width: SketchMetrics.canvas, height: SketchMetrics.canvas)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var drawing: some View {
        switch sketch {
        case .swipeDownFromTopRight:
            SketchPhone {
                SketchTiles(rows: 2, top: 46).opacity(0.35)
                SketchArrow(systemName: "arrow.down").position(x: 39, y: 28)
                SketchTouch().position(x: 39, y: 11)
            }
        case .tapPlusAtTopLeft:
            SketchPhone {
                SketchTiles(rows: 2, top: 36)
                SketchRoundButton(systemName: "plus").position(x: 11, y: 15)
                SketchTouch().position(x: 11, y: 15)
            }
        case .tapAddAControl:
            SketchPhone {
                SketchTiles(rows: 2, top: 20).opacity(0.35)
                SketchPill(width: 38, systemName: "plus").position(x: 25, y: 66)
                SketchTouch().position(x: 38, y: 70)
            }
        case .searchForTheControl:
            SketchPhone {
                SketchSearchField().position(x: 25, y: 15)
                SketchBulb(diameter: 24).position(x: 23, y: 42)
                SketchTouch().position(x: 35, y: 55)
            }
        case .touchAndHoldLockScreen:
            SketchPhone {
                SketchLockScreen()
                SketchTouch(isHeld: true).position(x: 25, y: 50)
            }
        case .tapCustomizeThenLockScreen:
            HStack(spacing: 8) {
                SketchPhone(width: 32, height: 56, fill: Theme.sun) {
                    SketchLockScreen(scale: 0.64, ink: Theme.onColor)
                    SketchTouch().position(x: 16, y: 34)
                }
                SketchPhone(width: 32, height: 56) {
                    SketchTiles(rows: 2, top: 12, size: 8, spacing: 4)
                }
            }
        case .removeABottomButton:
            SketchPhone {
                SketchLockScreen(showsBottomButtons: false).opacity(0.35)
                SketchCircle(diameter: 14).position(x: 13, y: 67)
                SketchCircle(diameter: 14).position(x: 37, y: 67)
                SketchRoundButton(systemName: "minus", diameter: 12, fill: Theme.tomato).position(x: 19, y: 59)
                SketchTouch().position(x: 28, y: 51)
            }
        case .addABottomButton:
            SketchPhone {
                SketchLockScreen(showsBottomButtons: false).opacity(0.35)
                Circle().fill(Theme.sun).frame(width: 24, height: 24).position(x: 14, y: 66)
                SketchBulb(diameter: 17).position(x: 14, y: 66)
                SketchCircle(diameter: 14).position(x: 37, y: 67)
            }
        case .openActionButtonSettings:
            SketchPhone(sideButton: true) {
                SketchListRows(highlighted: 1)
                SketchTouch().position(x: 38, y: 44)
            }
        case .swipeToControls:
            SketchPhone {
                SketchCarousel()
                SketchArrow(systemName: "arrow.left.and.right").position(x: 25, y: 70)
            }
        case .tapChooseAControl:
            SketchPhone(sideButton: true) {
                SketchCarousel(top: 10)
                SketchPill(width: 36).position(x: 25, y: 66)
                SketchTouch().position(x: 37, y: 70)
            }
        case .touchAndHoldHomeScreen:
            SketchPhone {
                SketchTiles(rows: 2, top: 12, columns: 3, size: 10, spacing: 5)
                SketchTouch(isHeld: true).position(x: 25, y: 58)
            }
        case .tapEditThenAddWidget:
            SketchPhone {
                SketchTiles(rows: 3, top: 22, columns: 3, size: 10, spacing: 5).opacity(0.35)
                SketchPill(width: 18, height: 9).position(x: 13, y: 12)
                SketchTouch().position(x: 21, y: 17)
            }
        case .chooseBufSnap:
            SketchPhone {
                SketchSearchField().position(x: 25, y: 15)
                SketchListRows(top: 32, highlighted: 0, showsAppIcon: true)
                SketchTouch().position(x: 38, y: 36)
            }
        case .addTheWidget:
            SketchPhone {
                SketchWidget().position(x: 25, y: 34)
                SketchPill(width: 36, fill: Theme.tomato).position(x: 25, y: 66)
                SketchTouch().position(x: 37, y: 70)
            }
        }
    }
}
