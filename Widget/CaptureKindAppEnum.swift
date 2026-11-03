import AppIntents
import BufferSnapCore

/// `Capture.Kind` as an App Intents parameter. Core stays free of App Intents, so the mirror lives here.
enum CaptureKindAppEnum: String, AppEnum, CaseIterable {
    case text
    case audio
    case photo
    case video

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Capture kind"

    static let caseDisplayRepresentations: [CaptureKindAppEnum: DisplayRepresentation] = [
        .text: "Text",
        .audio: "Voice",
        .photo: "Photo",
        .video: "Video",
    ]

    var captureKind: Capture.Kind {
        switch self {
        case .text:
            .text
        case .audio:
            .audio
        case .photo:
            .photo
        case .video:
            .video
        }
    }
}
