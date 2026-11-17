import BufferSnapCore
import SwiftUI

/// A sketch's touch acting out its step's gesture, over and over: it lands where `SketchTouch` sits, taps, holds or
/// swipes, rests, then lifts and starts again. With Reduce Motion on, the sketch draws `SketchTouch` instead
/// (`docs/decisions/109-snapshots-draw-the-still.md`).
///
/// `revealing` is what the tap brings up, such as the bulb that takes a Lock Screen button's place: it pops in under
/// the touch once the tap lands, and fades out after it lifts.
struct SketchGestureTouch<Revealed: View>: View {
    let gesture: DictationPlacementStep.Gesture
    @ViewBuilder var revealing: Revealed

    var body: some View {
        let distance = swipeDistance
        KeyframeAnimator(initialValue: TouchPose.lifted, repeating: true) { pose in
            ZStack {
                revealing
                    .scaleEffect(0.6 + 0.4 * pose.reveal)
                    .opacity(pose.reveal)
                ZStack {
                    Circle()
                        .strokeBorder(Theme.tomato, lineWidth: SketchMetrics.line)
                        .frame(width: 26, height: 26)
                        .scaleEffect(pose.ringScale)
                        .opacity(pose.ringOpacity)
                    SketchTouch()
                        .scaleEffect(pose.scale)
                }
                .offset(x: distance.width * pose.travel, y: distance.height * pose.travel)
                .opacity(pose.opacity)
            }
        } keyframes: { _ in
            TouchKeyframes.cycle(gesture)
        }
    }

    /// How far a swipe moves the touch.
    private var swipeDistance: CGSize {
        switch gesture {
        case .swipeDown:
            CGSize(width: 0, height: 24)
        case .swipeLeft:
            CGSize(width: -22, height: 0)
        case .tap, .touchAndHold:
            .zero
        }
    }
}

extension SketchGestureTouch where Revealed == EmptyView {
    init(gesture: DictationPlacementStep.Gesture) {
        self.init(gesture: gesture) {
            EmptyView()
        }
    }
}

/// Where `SketchGestureTouch` is in its cycle.
struct TouchPose {
    /// Lifted off the screen, where each cycle starts and ends: unseen, and a little larger, as if above the glass.
    static let lifted = TouchPose(opacity: 0, scale: 1.4, ringScale: 0.58, ringOpacity: 0, travel: 0, reveal: 0)

    /// How much of the touch shows.
    var opacity: Double
    /// The dot's size: 1 at rest, smaller while pressed.
    var scale: CGFloat
    /// The ring around the dot, as a fraction of `SketchTouch`'s held ring (0.58 sits on the dot's edge): a tap's
    /// ripple, or a touch and hold's ring.
    var ringScale: CGFloat
    var ringOpacity: Double
    /// How far along its swipe the touch is, 0 to 1.
    var travel: CGFloat
    /// How much of what the tap brings up shows, 0 to 1.
    var reveal: Double
}

/// One cycle of `SketchGestureTouch`, 2.8 seconds: the touch lands (0–0.3 s), acts out the gesture (from 0.5 s), rests
/// until 2 s, lifts by 2.3 s and stays away until the next cycle. Every track lasts the whole cycle and ends on
/// `TouchPose.lifted`, where the next one starts, so the loop never jumps.
private enum TouchKeyframes {
    @KeyframesBuilder<TouchPose>
    static func cycle(_ gesture: DictationPlacementStep.Gesture) -> some Keyframes<TouchPose> {
        KeyframeTrack(\.opacity) {
            CubicKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 1.7)
            CubicKeyframe(0, duration: 0.3)
            LinearKeyframe(0, duration: 0.5)
        }
        KeyframeTrack(\.scale) {
            scale(gesture)
        }
        KeyframeTrack(\.ringScale) {
            ringScale(gesture)
        }
        KeyframeTrack(\.ringOpacity) {
            ringOpacity(gesture)
        }
        KeyframeTrack(\.travel) {
            travel(gesture)
        }
        KeyframeTrack(\.reveal) {
            LinearKeyframe(0, duration: 0.65)
            CubicKeyframe(1, duration: 0.25)
            LinearKeyframe(1, duration: 1.4)
            CubicKeyframe(0, duration: 0.3)
            LinearKeyframe(0, duration: 0.2)
        }
    }

    /// A tap presses the dot and lets go; a touch and hold presses it until it lifts.
    @KeyframeTrackContentBuilder<CGFloat>
    private static func scale(_ gesture: DictationPlacementStep.Gesture) -> some KeyframeTrackContent<CGFloat> {
        CubicKeyframe(1, duration: 0.3)
        switch gesture {
        case .tap:
            LinearKeyframe(1, duration: 0.2)
            CubicKeyframe(0.8, duration: 0.15)
            CubicKeyframe(1, duration: 0.2)
            LinearKeyframe(1, duration: 1.45)
        case .touchAndHold:
            LinearKeyframe(1, duration: 0.2)
            CubicKeyframe(0.85, duration: 0.15)
            LinearKeyframe(0.85, duration: 1.35)
            CubicKeyframe(1, duration: 0.3)
        case .swipeDown, .swipeLeft:
            LinearKeyframe(1, duration: 2)
        }
        LinearKeyframe(TouchPose.lifted.scale, duration: 0.5)
    }

    /// A tap sends a ripple out from the dot; a touch and hold grows `SketchTouch`'s held ring around it.
    @KeyframeTrackContentBuilder<CGFloat>
    private static func ringScale(_ gesture: DictationPlacementStep.Gesture) -> some KeyframeTrackContent<CGFloat> {
        switch gesture {
        case .tap:
            LinearKeyframe(TouchPose.lifted.ringScale, duration: 0.65)
            CubicKeyframe(1.5, duration: 0.6)
            LinearKeyframe(1.5, duration: 1.05)
        case .touchAndHold:
            LinearKeyframe(TouchPose.lifted.ringScale, duration: 0.5)
            CubicKeyframe(1, duration: 1)
            LinearKeyframe(1, duration: 0.8)
        case .swipeDown, .swipeLeft:
            LinearKeyframe(TouchPose.lifted.ringScale, duration: 2.3)
        }
        LinearKeyframe(TouchPose.lifted.ringScale, duration: 0.5)
    }

    @KeyframeTrackContentBuilder<Double>
    private static func ringOpacity(_ gesture: DictationPlacementStep.Gesture) -> some KeyframeTrackContent<Double> {
        switch gesture {
        case .tap:
            LinearKeyframe(0, duration: 0.65)
            MoveKeyframe(0.6)
            CubicKeyframe(0, duration: 0.6)
            LinearKeyframe(0, duration: 1.55)
        case .touchAndHold:
            LinearKeyframe(0, duration: 0.5)
            CubicKeyframe(0.6, duration: 1)
            LinearKeyframe(0.6, duration: 0.8)
            LinearKeyframe(0, duration: 0.5)
        case .swipeDown, .swipeLeft:
            LinearKeyframe(0, duration: 2.8)
        }
    }

    /// A swipe moves the touch, then takes it back once it's lifted and unseen.
    @KeyframeTrackContentBuilder<CGFloat>
    private static func travel(_ gesture: DictationPlacementStep.Gesture) -> some KeyframeTrackContent<CGFloat> {
        switch gesture {
        case .swipeDown, .swipeLeft:
            LinearKeyframe(0, duration: 0.5)
            CubicKeyframe(1, duration: 0.8)
            LinearKeyframe(1, duration: 1)
            LinearKeyframe(0, duration: 0.5)
        case .tap, .touchAndHold:
            LinearKeyframe(0, duration: 2.8)
        }
    }
}
