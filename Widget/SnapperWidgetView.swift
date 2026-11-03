import SwiftUI
import WidgetKit

/// The widget's face: how many captures exist, and one button per kind.
struct SnapperWidgetView: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count) captured")
                .font(.headline)
                // Don't animate: with the default transition the simulator kept drawing the previous count until the
                // next redraw, so each tap appeared to show one too few.
                .contentTransition(.identity)
            HStack(spacing: 8) {
                ForEach(CaptureKindAppEnum.allCases, id: \.self) { kind in
                    Button(intent: MockCaptureIntent(kind: kind)) {
                        VStack(spacing: 4) {
                            Image(systemName: kind.symbolName)
                                .font(.title3)
                            Text(kind.label)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

extension CaptureKindAppEnum {
    /// The same symbols the app's capture list uses (`CaptureRow`), so a capture looks the same in both.
    fileprivate var symbolName: String {
        switch self {
        case .text:
            "textformat"
        case .audio:
            "mic"
        case .photo:
            "camera"
        case .video:
            "video"
        }
    }

    fileprivate var label: String {
        switch self {
        case .text:
            "Text"
        case .audio:
            "Voice"
        case .photo:
            "Photo"
        case .video:
            "Video"
        }
    }
}
