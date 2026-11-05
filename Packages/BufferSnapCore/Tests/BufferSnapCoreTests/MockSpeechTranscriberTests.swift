import BufferSnapCore
import Testing

struct MockSpeechTranscriberTests {
    @Test func streamYieldsWhatItHearsThenTheFinalWordsAndEnds() async throws {
        let speech = MockSpeechTranscriber(finalWords: "Hello there.")

        let stream = try await speech.start()
        await speech.hear("Hello")
        await speech.finish()

        var heard: [String] = []
        for try await words in stream {
            heard.append(words)
        }
        #expect(heard == ["Hello", "Hello there."])
    }

    @Test func askingForPermissionKeepsTheAnswer() async {
        let speech = MockSpeechTranscriber(permission: .undetermined, answer: .microphoneDenied)

        #expect(await speech.permission() == .undetermined)
        #expect(await speech.requestPermission() == .microphoneDenied)
        #expect(await speech.permission() == .microphoneDenied)
    }
}
