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

    @Test("Decodes the additive rejectedDiagrams count and defaults it to zero")
    func rejectedDiagrams() throws {
        let ready = try BrowserRuntimeReport(messageBody: [
            "version": 1, "status": "ready", "requiredFeatures": ["mermaid"],
            "failedFeatures": [], "rejectedDiagrams": 2
        ])
        let failed = try BrowserRuntimeReport(messageBody: [
            "version": 1, "status": "failed", "requiredFeatures": ["mermaid"],
            "failedFeatures": ["mermaid"], "rejectedDiagrams": 1, "detail": "Pele mount failed: boom"
        ])
        let absent = try BrowserRuntimeReport(messageBody: [
            "version": 1, "status": "ready", "requiredFeatures": ["mermaid"], "failedFeatures": []
        ])

        #expect(ready == .ready(requiredFeatures: [.mermaid], rejectedDiagrams: 2))
        #expect(
            failed == .failed(
                requiredFeatures: [.mermaid],
                failedFeatures: [.mermaid],
                detail: "Pele mount failed: boom",
                rejectedDiagrams: 1
            )
        )
        #expect(absent == .ready(requiredFeatures: [.mermaid], rejectedDiagrams: 0))
        for invalid: Any in [-1, "2", 1.5] {
            #expect(throws: BrowserRuntimeError.self) {
                try BrowserRuntimeReport(messageBody: [
                    "version": 1, "status": "ready", "requiredFeatures": [],
                    "failedFeatures": [], "rejectedDiagrams": invalid
                ])
            }
        }
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
