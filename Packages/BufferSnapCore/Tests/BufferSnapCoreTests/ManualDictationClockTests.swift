import Foundation
import Testing

struct ManualDictationClockTests {
    @Test func aSleepThatStartsAfterItsDeadlinePassedReturnsAtOnce() async throws {
        let clock = ManualDictationClock()
        let deadline = clock.now + 3

        clock.advance(by: 3)

        try await clock.sleep(until: deadline)
        #expect(clock.now == deadline)
    }

    @Test func aCancelledSleepThrows() async {
        let clock = ManualDictationClock()
        let sleep = Task {
            try await clock.sleep(until: clock.now + 3)
        }

        sleep.cancel()

        await #expect(throws: CancellationError.self) {
            try await sleep.value
        }
    }
}
