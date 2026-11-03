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

    // The mocked app's seed: the capture list must show every kind and every status.
    @Test func samplesCoverEveryKindAndStatusWithUniqueIDs() {
        let samples = Capture.samples()

        #expect(samples.count == 5)
        #expect(Set(samples.map(\.kind)) == Set(Capture.Kind.allCases))
        #expect(Set(samples.map(\.status)) == Set(Capture.Status.allCases))
        #expect(Set(samples.map(\.id)).count == samples.count)
    }

    @Test func samplesAreNewestFirstAndBeforeNow() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let dates = Capture.samples(relativeTo: now).map(\.createdAt)

        #expect(dates == dates.sorted(by: >))
        #expect(dates.allSatisfy { $0 < now })
    }

    // The app seeds relative to launch time, so only the dates may depend on `now`.
    @Test func samplesShiftWithNowButKeepTheirIDs() {
        let later = Capture.samplesReferenceDate.addingTimeInterval(3_600)
        let base = Capture.samples()
        let shifted = Capture.samples(relativeTo: later)

        #expect(shifted.map(\.id) == base.map(\.id))
        #expect(shifted.map(\.createdAt) == base.map { $0.createdAt.addingTimeInterval(3_600) })
    }

    @Test(arguments: Capture.Kind.allCases)
    func mockIsPendingAndNamesItsKind(kind: Capture.Kind) {
        let capture = Capture.mock(kind: kind)

        #expect(capture.kind == kind)
        #expect(capture.status == .pending)
        #expect(capture.text == "Mock \(kind.rawValue) capture")
    }
}
