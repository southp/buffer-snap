import Foundation
import Testing

@testable import BufferSnapCore

struct ProjectLinksTests {
    /// Most people using BufSnap have no GitHub account, so Report a Problem opens the page that also offers email.
    @Test func reportProblemOpensTheSupportPagesReportSection() {
        let url = ProjectLinks.reportProblem

        #expect(url.host() == "southp.github.io")
        #expect(url.path() == "/buffer-snap/support/")
        #expect(url.fragment() == "report")
    }

    @Test func sourceCodeOpensTheRepo() {
        #expect(ProjectLinks.sourceCode.absoluteString == "https://github.com/southp/buffer-snap")
    }
}
