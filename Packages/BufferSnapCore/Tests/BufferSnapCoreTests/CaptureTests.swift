import BufferSnapCore
import Foundation
import Testing

struct CaptureTests {
    // The App Group store (#4) persists captures as JSON, so every field must survive a round trip.
    @Test(arguments: Capture.Kind.allCases)
    func codableRoundTripKeepsEveryField(kind: Capture.Kind) throws {
        let capture = Capture(
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1_000),
            status: .failed,
            text: "Hello"
        )

        let data = try JSONEncoder().encode(capture)
        let decoded = try JSONDecoder().decode(Capture.self, from: data)

        #expect(decoded == capture)
    }
}
