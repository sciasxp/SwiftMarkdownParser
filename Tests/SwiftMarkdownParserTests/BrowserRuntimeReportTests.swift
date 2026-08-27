#if os(macOS) && canImport(WebKit)
import Testing
@testable import SwiftMarkdownParser

@Suite("Browser runtime adapter")
struct BrowserRuntimeReportTests {
    @Test("Accepts a ready report")
    func ready() throws {
        let report = try BrowserRuntimeReport(messageBody: [
            "version": 1,
            "status": "ready",
            "requiredFeatures": ["mermaid", "katex"],
            "failedFeatures": [],
        ])
        #expect(report == .ready(requiredFeatures: [.mermaid, .katex]))
    }

    @Test("Preserves structured runtime failure context")
    func failure() throws {
        let report = try BrowserRuntimeReport(
            messageBody: [
                "version": 1,
                "status": "failed",
                "requiredFeatures": ["katex"],
                "failedFeatures": ["katex"],
                "detail": "KaTeX runtime unavailable",
            ]
        )
        #expect(
            report == .failed(
                requiredFeatures: [.katex],
                failedFeatures: [.katex],
                detail: "KaTeX runtime unavailable"
            )
        )
    }

    @Test("Accepts legacy unversioned reports internally")
    func legacy() throws {
        let ready = try BrowserRuntimeReport(messageBody: ["status": "ready"])
        let failed = try BrowserRuntimeReport(messageBody: ["status": "failed", "detail": "Unavailable"])

        #expect(ready == .ready(requiredFeatures: []))
        #expect(
            failed == .failed(
                requiredFeatures: [],
                failedFeatures: [],
                detail: "Unavailable"
            )
        )
    }

    @Test("Rejects incompatible or malformed versioned reports")
    func malformed() {
        let messages: [[String: Any]] = [
            ["version": 2, "status": "ready", "requiredFeatures": [], "failedFeatures": []],
            ["version": 1, "status": "ready", "requiredFeatures": ["unknown"], "failedFeatures": []],
            ["version": 1, "status": "ready", "requiredFeatures": ["mermaid"], "failedFeatures": ["mermaid"]],
            ["version": 1, "status": "failed", "requiredFeatures": [], "failedFeatures": ["mermaid"]],
            ["version": 1, "status": "ready", "requiredFeatures": ["mermaid", "mermaid"], "failedFeatures": []],
            ["unexpected": true],
        ]

        for message in messages {
            #expect(throws: BrowserRuntimeError.self) {
                try BrowserRuntimeReport(messageBody: message)
            }
        }
    }
}
#endif
