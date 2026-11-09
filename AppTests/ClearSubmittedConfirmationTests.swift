import Testing

@testable import BufferSnap

struct ClearSubmittedConfirmationTests {
    @Test func saysHowManyAndThatTheyStayInBuffer() {
        let confirmation = ClearSubmittedConfirmation(ideaCount: 3)

        #expect(confirmation.title == "Clear 3 submitted ideas?")
        #expect(confirmation.message == "They stay in Buffer, and are only removed from this iPhone.")
    }

    @Test func usesTheSingularForOneIdea() {
        let confirmation = ClearSubmittedConfirmation(ideaCount: 1)

        #expect(confirmation.title == "Clear 1 submitted idea?")
        #expect(confirmation.message == "It stays in Buffer, and is only removed from this iPhone.")
    }
}
