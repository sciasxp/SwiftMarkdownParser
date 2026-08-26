#if os(macOS) && canImport(WebKit)
import Testing
@testable import SwiftMarkdownParser

@Suite("Browser runtime adapter")
struct BrowserRuntimeReportTests {
    @Test("Accepts a ready report")
    func ready() throws {
        let report = try BrowserRuntimeReport(messageBody: ["status": "ready"])
        #expect(report == .ready)
    }

    @Test("Preserves an external runtime failure")
    func failure() throws {
        let report = try BrowserRuntimeReport(
            messageBody: ["status": "failed", "detail": "KaTeX runtime unavailable"]
        )
        #expect(report == .failed("KaTeX runtime unavailable"))
    }

    @Test("Rejects malformed reports")
    func malformed() {
        #expect(throws: BrowserRuntimeError.self) {
            try BrowserRuntimeReport(messageBody: ["unexpected": true])
        }
    }
}
#endif
