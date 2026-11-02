import Testing

@testable import BufferSnap

// Placeholder that proves the test target builds against the app and runs.
// Replaced by snapshot tests in #13.
@Test func appModuleLoads() {
    _ = BufferSnapApp.self
    #expect(Bool(true))
}
