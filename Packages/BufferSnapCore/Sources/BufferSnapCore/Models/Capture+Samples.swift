import Foundation

extension Capture {
    /// One capture of each kind with fixed ids and dates, newest first, to seed the mocked app and previews.
    public static let samples: [Capture] = [
        Capture(id: sampleID(1), kind: .text, createdAt: sampleDate(minutesAgo: 5), text: "Idea for Friday's post"),
        Capture(id: sampleID(2), kind: .photo, createdAt: sampleDate(minutesAgo: 60), status: .submitted),
        Capture(id: sampleID(3), kind: .audio, createdAt: sampleDate(minutesAgo: 180), status: .failed),
        Capture(id: sampleID(4), kind: .video, createdAt: sampleDate(minutesAgo: 1_440), text: "Launch teaser"),
    ]

    private static func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }

    // Fixed "now" (2026-01-01 00:00 UTC) so the samples look the same on every run.
    private static func sampleDate(minutesAgo: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_767_225_600 - minutesAgo * 60)
    }
}
