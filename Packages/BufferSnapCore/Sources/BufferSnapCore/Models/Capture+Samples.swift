import Foundation

extension Capture {
    /// The "now" that `samples()` dates its captures against by default: 2026-01-01 00:00 UTC.
    /// Snapshot tests render relative timestamps against this date too, so they look the same on every run.
    public static let samplesReferenceDate = Date(timeIntervalSince1970: 1_767_225_600)

    /// Five captures with fixed ids, newest first, that together cover every kind and every status.
    /// They're dated minutes to days before `now`, for tests and snapshots. The running app never shows them.
    public static func samples(relativeTo now: Date = samplesReferenceDate) -> [Capture] {
        func minutesAgo(_ minutes: TimeInterval) -> Date {
            now.addingTimeInterval(-minutes * 60)
        }
        return [
            Capture(id: sampleID(1), kind: .text, createdAt: minutesAgo(5), text: "Idea for Friday's post"),
            Capture(id: sampleID(2), kind: .photo, createdAt: minutesAgo(60), status: .submitted),
            Capture(
                id: sampleID(3),
                kind: .text,
                createdAt: minutesAgo(180),
                status: .failed,
                text: "Newsletter intro"
            ),
            Capture(
                id: sampleID(4),
                kind: .text,
                createdAt: minutesAgo(1_440),
                status: .submitted,
                text: "Thread hook idea"
            ),
            Capture(id: sampleID(5), kind: .photo, createdAt: minutesAgo(4_320), text: "Launch teaser"),
        ]
    }

    private static func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }
}
