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
            text: "Hello",
            batchID: UUID()
        )

        let data = try JSONEncoder().encode(capture)
        let decoded = try JSONDecoder().decode(Capture.self, from: data)

        #expect(decoded == capture)
    }

    /// What an install from before batching has on disk must still read, as captures that aren't in a batch yet.
    @Test func aFileFromBeforeBatchesStillDecodes() throws {
        let json = #"""
            [{"id":"00000000-0000-0000-0000-000000000001","kind":"text","createdAt":1000,
              "status":"pending","text":"Old"}]
            """#

        let decoded = try JSONDecoder().decode([Capture].self, from: Data(json.utf8))

        #expect(decoded.map(\.text) == ["Old"])
        #expect(decoded.map(\.batchID) == [nil])
    }

    /// A capture that isn't in a batch writes no key, so an older build reading the file sees what it always did.
    @Test func noBatchWritesNoKey() throws {
        let json = String(bytes: try JSONEncoder().encode(Capture(kind: .text)), encoding: .utf8)

        #expect(json?.contains("batchID") == false)
    }

    // The snapshot tests' fixture: the capture list must show every kind and every status.
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

    // Only the dates may depend on `now`.
    @Test func samplesShiftWithNowButKeepTheirIDs() {
        let later = Capture.samplesReferenceDate.addingTimeInterval(3_600)
        let base = Capture.samples()
        let shifted = Capture.samples(relativeTo: later)

        #expect(shifted.map(\.id) == base.map(\.id))
        #expect(shifted.map(\.createdAt) == base.map { $0.createdAt.addingTimeInterval(3_600) })
    }
}
