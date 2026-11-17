import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The guide's moving touch loops without a jump: every gesture's cycle starts and ends on `TouchPose.lifted`, so one
/// cycle's last frame is the next one's first. Read from the keyframes themselves, not from a running animation, so
/// nothing here depends on timing (`docs/decisions/109-snapshots-draw-the-still.md`).
@MainActor
struct SketchGestureTouchTests {
    @Test(arguments: DictationPlacementStep.Gesture.allCases)
    func theCycleEndsWhereItStarts(gesture: DictationPlacementStep.Gesture) {
        let timeline = KeyframeTimeline(initialValue: TouchPose.lifted) {
            TouchKeyframes.cycle(gesture)
        }

        #expect(isLifted(timeline.value(time: 0)))
        #expect(isLifted(timeline.value(time: timeline.duration)))
    }

    /// Whether `pose` is `TouchPose.lifted`, give or take floating-point rounding from the keyframe curves.
    private func isLifted(_ pose: TouchPose) -> Bool {
        let lifted = TouchPose.lifted
        let pairs: [(Double, Double)] = [
            (pose.opacity, lifted.opacity),
            (pose.scale, lifted.scale),
            (pose.ringScale, lifted.ringScale),
            (pose.ringOpacity, lifted.ringOpacity),
            (pose.travel, lifted.travel),
            (pose.reveal, lifted.reveal),
        ]
        return pairs.allSatisfy { abs($0 - $1) < 1e-9 }
    }
}
