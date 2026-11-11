#if os(macOS) && canImport(WebKit)
import Foundation
import Testing
import AppKit
import WebKit
@testable import SwiftMarkdownParser

/// Runs the generated bootstrap for real in WebKit and reads the readiness report and the DOM.
@MainActor
@Suite("Pele diagram runtime in WebKit", .serialized)
struct PeleDiagramRuntimeTests {
    private static let graph = "```mermaid\ngraph TD\nA --> B\n```"
    private static let invalidSource = "not a diagram </script><b>x</b>"
    private static let invalidGraph = "```mermaid\n\(invalidSource)\n```"

    private static func bundled(
        messages: MermaidConfiguration.Messages = .init(diagramFailed: "Falha localizada"),
        zoom: MermaidConfiguration.Zoom = .auto
    ) -> HTMLRenderOptions {
        HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(assetSource: .bundled, zoom: zoom, messages: messages)
        )
    }

    private static func custom(_ script: URL) -> HTMLRenderOptions {
        HTMLRenderOptions(mermaidConfiguration: MermaidConfiguration(assetSource: .custom(scriptURL: script)))
    }

    @Test("Without diagrams the Pele runtime is not loaded and the report is ready")
    func zeroDiagrams() async throws {
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: "- [ ] a task", options: Self.bundled())
        let report = try await page.waitForReport()

        #expect(report.status == "ready")
        #expect(report.requiredFeatures == ["taskLists"])
        #expect(report.failedFeatures.isEmpty)
        #expect(report.rejectedDiagrams == 0)
        #expect(try await page.string("typeof pele") == "undefined")
    }

    @Test("A valid diagram is drawn and the report is ready")
    func oneValidDiagram() async throws {
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: Self.graph, options: Self.bundled())
        let report = try await page.waitForReport()
        let dom = try await page.dom()

        #expect(report.status == "ready")
        #expect(report.requiredFeatures == ["mermaid"])
        #expect(report.failedFeatures.isEmpty)
        #expect(report.rejectedDiagrams == 0)
        #expect(dom.svgs == 1)
        #expect(dom.preMermaid == 0)
        #expect(dom.peleErrors == 0)
        #expect(dom.diagramErrors == 0)
    }

    @Test("A rejected diagram shows the configured message and its source and does not stop the others")
    func middleDiagramRejected() async throws {
        let markdown = [Self.graph, Self.invalidGraph, Self.graph].joined(separator: "\n\n")
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: markdown, options: Self.bundled())
        let report = try await page.waitForReport()
        let dom = try await page.dom()

        #expect(report.status == "ready")
        #expect(report.failedFeatures.isEmpty)
        #expect(report.rejectedDiagrams == 1)
        #expect(dom.svgs == 2)
        #expect(dom.diagramErrors == 1)
        #expect(dom.peleErrors == 0)
        #expect(dom.bold == 0)
        #expect(dom.preMermaid == 0)
        #expect(dom.errorMessages == ["Falha localizada"])
        #expect(dom.errorSources == [Self.invalidSource])  // the fence adds a trailing newline, trimmed by `dom()`
    }

    @Test("A missing runtime file reports mermaid as failed and keeps the sources")
    func customRuntimeMissing() async throws {
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/pele.global.js")
        let options = Self.custom(missing)
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: [Self.graph, Self.graph].joined(separator: "\n\n"), options: options)
        let report = try await page.waitForReport()
        let dom = try await page.dom()

        #expect(report.status == "failed")
        #expect(report.failedFeatures == ["mermaid"])
        #expect(dom.preMermaid == 2)
        #expect(dom.svgs == 0)
    }

    @Test("A runtime script that does not define pele reports mermaid as failed")
    func runtimeWithoutPele() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let script = try directory.write("empty.js", "window.somethingElse = true;")
        let options = Self.custom(script)
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: Self.graph, options: options, in: directory)
        let report = try await page.waitForReport()
        let dom = try await page.dom()

        #expect(report.status == "failed")
        #expect(report.failedFeatures == ["mermaid"])
        #expect(report.detail == "Pele runtime unavailable")
        #expect(dom.preMermaid == 1)
    }

    @Test("An exception from mount shows the source in place and the later diagrams are still mounted")
    func mountThrows() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let script = try directory.write(
            "pele-stub.js",
            """
            window.pele = {
                mount: function(element, source, options) {
                    if (source.indexOf('THROW') >= 0) {
                        element.innerHTML = '<svg data-partial="1" aria-roledescription="stub"></svg>';
                        throw new Error('boom');
                    }
                    element.innerHTML = '<svg aria-roledescription="stub"></svg>';
                }
            };
            """
        )
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                assetSource: .custom(scriptURL: script),
                messages: .init(diagramFailed: "Falha localizada")
            )
        )
        let throwing = "```mermaid\ngraph TD\nTHROW --> B\n```"
        let markdown = [Self.graph, throwing, Self.graph, Self.graph].joined(separator: "\n\n")
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: markdown, options: options, in: directory)
        let report = try await page.waitForReport()
        let dom = try await page.dom()

        #expect(report.status == "failed")
        #expect(report.failedFeatures == ["mermaid"])
        #expect(report.rejectedDiagrams == 1)
        #expect(report.detail == "Pele mount failed: boom")
        #expect(dom.svgs == 3)
        #expect(try await page.int("document.querySelectorAll('[data-partial]').length") == 0)
        #expect(dom.preMermaid == 0)
        #expect(dom.diagramErrors == 1)
        #expect(dom.errorMessages == ["Falha localizada"])
        #expect(dom.errorSources == ["graph TD\nTHROW --> B"])
    }

    @Test(
        "The report waits for fonts, and for two animation frames only while the page is visible",
        arguments: [0, 300], ["visible", "hidden"]
    )
    func readyWaitsForFontsAndFrames(fontDelay: Int, visibility: String) async throws {
        let directory = try TemporaryDirectory()
        defer { directory.remove() }
        let script = try directory.write(
            "pele-stub.js",
            """
            (function() {
                let frames = 0;
                let mountedAt = 0;
                // A web view that is not on screen never runs animation frames (the bootstrap then falls back
                // to its time limit), so frames are simulated to observe how many the bootstrap waits for.
                window.requestAnimationFrame = function(callback) {
                    return setTimeout(function() { frames += 1; callback(performance.now()); }, 16);
                };
                // A hidden page (the PDF export window, or no window at all) is reported without frames.
                Object.defineProperty(document, 'visibilityState', {
                    configurable: true,
                    get: function() { return '\(visibility)'; }
                });
                if (\(fontDelay) > 0) {
                    Object.defineProperty(document.fonts, 'ready', {
                        configurable: true,
                        value: new Promise(function(resolve) { setTimeout(resolve, \(fontDelay)); })
                    });
                }
                window.pele = {
                    mount: function(element) {
                        if (!mountedAt) { mountedAt = performance.now(); }
                        element.innerHTML = '<svg aria-roledescription="stub"></svg>';
                    }
                };
                window.addEventListener('swift-markdown-runtime', function() {
                    window.__probe = { elapsed: performance.now() - mountedAt, frames: frames };
                });
            })();
            """
        )
        let options = Self.custom(script)
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: Self.graph, options: options, in: directory)
        let report = try await page.waitForReport()
        let probe: Probe = try await page.json("window.__probe")

        #expect(report.status == "ready")
        #expect(probe.frames == (visibility == "visible" ? 2 : 0))
        #expect(probe.elapsed >= Double(fontDelay) - 20)
        #expect(probe.elapsed < Double(fontDelay) + 1000)
    }

    @Test("Diagram links follow the package schemes: https stays, tel is dropped")
    func linkSchemes() async throws {
        let markdown = """
        ```mermaid
        graph TD
        A --> B
        click A href "https://example.com/page"
        click B href "tel:+5511999999999"
        ```
        """
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: markdown, options: Self.bundled())
        let report = try await page.waitForReport()

        #expect(report.status == "ready")
        #expect(report.rejectedDiagrams == 0)
        let https = try await page.int("document.querySelectorAll('.pele-diagram a[href^=\"https:\"]').length")
        let tel = try await page.int("document.querySelectorAll('.pele-diagram a[href^=\"tel:\"]').length")
        #expect(https >= 1)
        #expect(tel == 0)
    }

    @Test("The zoom controls carry the configured labels")
    func zoomLabels() async throws {
        let messages = MermaidConfiguration.Messages(
            diagramFailed: "Falhou", zoomIn: "Aproximar", zoomOut: "Afastar", reset: "Restaurar"
        )
        let page = RuntimePage()
        defer { page.close() }

        try await page.load(markdown: Self.graph, options: Self.bundled(messages: messages, zoom: .always))
        _ = try await page.waitForReport()

        let labels: [String] = try await page.json(
            "['.pele-zoom-in', '.pele-zoom-out', '.pele-zoom-reset'].map(function(selector) { "
                + "const button = document.querySelector(selector); "
                + "return button ? button.getAttribute('aria-label') : null; })"
        )
        #expect(labels == ["Aproximar", "Afastar", "Restaurar"])
    }
}

// MARK: - Harness

private struct Probe: Decodable {
    let elapsed: Double
    let frames: Int
}

private struct DOMSummary: Decodable {
    let svgs: Int
    let preMermaid: Int
    let diagramErrors: Int
    let peleErrors: Int
    let bold: Int
    let errorMessages: [String]
    let errorSources: [String]
}

private struct PageError: Error, CustomStringConvertible {
    let description: String
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pele-runtime-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ name: String, _ contents: String) throws -> URL {
        let file = url.appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

@MainActor
private final class RuntimePage: NSObject, WKScriptMessageHandler {
    struct Report: Decodable {
        let status: String
        let requiredFeatures: [String]
        let failedFeatures: [String]
        let rejectedDiagrams: Int
        let detail: String?
    }

    let webView: WKWebView
    /// WebKit runs animation frames only for a view that is in a window.
    private let window: NSWindow
    private(set) var report: Report?

    override init() {
        _ = NSApplication.shared
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: frame, configuration: configuration)
        window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.contentView = webView
        window.orderFrontRegardless()
        configuration.userContentController.add(self, name: "markdownRuntime")
    }

    func close() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "markdownRuntime")
        window.orderOut(nil)
    }

    func load(markdown: String, options: HTMLRenderOptions, in directory: TemporaryDirectory? = nil) async throws {
        let document = try SwiftMarkdownParser().parse(markdown)
        let html = try await HTMLRenderer(options: options).renderDocument(document)
        if let directory {
            let page = try directory.write("index.html", html)
            webView.loadFileURL(page, allowingReadAccessTo: directory.url)
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: message.body),
            let decoded = try? JSONDecoder().decode(Report.self, from: data)
        else { return }
        report = decoded
    }

    func waitForReport(timeout: Duration = .seconds(20)) async throws -> Report {
        let deadline = ContinuousClock.now + timeout
        while true {
            if let report { return report }
            guard ContinuousClock.now < deadline else {
                throw PageError(description: "No markdownRuntime report within \(timeout)")
            }
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    func json<T: Decodable>(_ expression: String) async throws -> T {
        let result = try await webView.evaluateJavaScript("JSON.stringify(\(expression))")
        guard let text = result as? String else {
            throw PageError(description: "No JSON result for \(expression)")
        }
        return try JSONDecoder().decode(T.self, from: Data(text.utf8))
    }

    func string(_ expression: String) async throws -> String {
        try await json(expression)
    }

    func int(_ expression: String) async throws -> Int {
        try await json(expression)
    }

    fileprivate func dom() async throws -> DOMSummary {
        try await json(
            """
            {
                svgs: document.querySelectorAll('.pele-diagram svg[aria-roledescription]').length,
                preMermaid: document.querySelectorAll('pre.mermaid').length,
                diagramErrors: document.querySelectorAll('.pele-diagram-error').length,
                peleErrors: document.querySelectorAll('.pele-error').length,
                bold: document.querySelectorAll('b').length,
                errorMessages: Array.from(document.querySelectorAll('.pele-diagram-error-message'))
                    .map(function(e) { return e.textContent; }),
                errorSources: Array.from(document.querySelectorAll('.pele-diagram-error code'))
                    .map(function(e) { return e.textContent.replace(/\\n$/, ''); })
            }
            """
        )
    }
}
#endif
