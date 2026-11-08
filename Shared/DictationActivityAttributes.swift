import ActivityKit
import BufferSnapCore

/// The Live Activity of a dictation started outside the app. The app starts it, and the widget draws it.
///
/// Everything it shows changes, so it's all in the content state, which is Core's `DictationStatus`.
struct DictationActivityAttributes: ActivityAttributes {
    typealias ContentState = DictationStatus
}
