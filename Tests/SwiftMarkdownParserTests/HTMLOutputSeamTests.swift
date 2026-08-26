import Foundation
import Testing
@testable import SwiftMarkdownParser

@Suite("HTML output seam")
struct HTMLOutputSeamTests {
    @Test("Renders fragments through one document-level interface")
    func fragment() async throws {
        let document = try SwiftMarkdownParser().parse("# Title\n\nA **deep** module.")

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<strong>deep</strong>"))
        #expect(!html.contains("<!DOCTYPE html>"))
    }

    @Test("Places feature resources in head of complete documents")
    func completeDocumentPlacesResources() async throws {
        let markdown = """
        Inline math $x^2$.

        ```mermaid
        graph TD
        A --> B
        ```
        """
        let document = try SwiftMarkdownParser().parse(markdown)

        let html = try await HTMLRenderer().renderDocument(
            document,
            metadata: HTMLDocumentMetadata(title: "Math & Diagrams", language: "pt-BR")
        )

        let headEnd = try #require(html.range(of: "</head>"))
        let bodyStart = try #require(html.range(of: "<body>"))
        let head = html[..<headEnd.lowerBound]
        let body = html[bodyStart.lowerBound...]

        #expect(head.contains("katex.min.css"))
        #expect(head.contains("mermaid.min.js"))
        #expect(body.contains("mermaid.initialize"))
        #expect(!body.contains("<link rel=\"stylesheet\""))
        #expect(html.contains("<html lang=\"pt-BR\">"))
        #expect(html.contains("<title>Math &amp; Diagrams</title>"))
    }

    @Test(
        "Owns Mermaid theme generation",
        arguments: [
            (MermaidConfiguration.Theme.dark, "\"theme\":\"dark\""),
            (.forest, "\"theme\":\"forest\""),
            (.neutral, "\"theme\":\"neutral\""),
            (.base, "\"theme\":\"base\""),
        ]
    )
    func mermaidThemes(theme: MermaidConfiguration.Theme, expected: String) async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(theme: theme)
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains(expected))
        #expect(html.contains("class=\"mermaid\""))
    }

    @Test("Uses configured KaTeX assets")
    func customKaTeXAssets() async throws {
        let document = try SwiftMarkdownParser().parse("$x + y$")
        let baseURL = try #require(URL(string: "https://assets.example/katex"))
        let configuration = KaTeXConfiguration(
            assetSource: .custom(baseURL: baseURL)
        )
        let options = HTMLRenderOptions(katexConfiguration: configuration)

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains("https://assets.example/katex/katex.min.css"))
        #expect(html.contains("https://assets.example/katex/katex.min.js"))
    }

    @Test("Omits disabled feature resources and keeps safe fallbacks")
    func disabledFeatures() async throws {
        let document = try SwiftMarkdownParser().parse("$x$\n\n```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(enabled: false),
            katexConfiguration: KaTeXConfiguration(enabled: false)
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(!html.contains("katex.min.js"))
        #expect(!html.contains("mermaid.initialize"))
        #expect(html.contains("<code class=\"language-mermaid\">"))
    }

    @Test("Rejects unsupported custom nodes atomically")
    func unsupportedNode() async {
        let document = AST.DocumentNode(children: [UnsupportedTestNode()])

        await #expect(throws: HTMLRenderingError.self) {
            try await HTMLRenderer().renderFragment(document)
        }
    }

    @Test("Includes each required runtime exactly once")
    func deduplicatesRuntimeAssets() async throws {
        let markdown = """
        $a$ and $b$.

        ```mermaid
        graph TD
        A --> B
        ```

        ```mermaid
        graph TD
        C --> D
        ```
        """
        let document = try SwiftMarkdownParser().parse(markdown)

        let html = try await HTMLRenderer().renderDocument(document)

        #expect(html.occurrences(of: "mermaid@10.9.1/dist/mermaid.min.js") == 1)
        #expect(html.occurrences(of: "katex@0.16.21/dist/katex.min.js") == 1)
        #expect(html.occurrences(of: "const requiredFeatures = [\"katex\",\"mermaid\"]") == 1)
    }

    @Test("Produces a self-contained document with bundled runtimes")
    func bundledAssets() async throws {
        let document = try SwiftMarkdownParser().parse("$x^2$\n\n```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(assetSource: .bundled),
            katexConfiguration: KaTeXConfiguration(assetSource: .bundled)
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(!html.contains("cdn.jsdelivr.net"))
        #expect(html.contains("data:font/woff2;base64,"))
        #expect(html.contains("mermaid.initialize(mermaidConfiguration)"))
        #expect(html.contains("katex.render(element.textContent"))
    }

    @Test("Rejects unsafe custom runtime URLs")
    func rejectsUnsafeAssetURL() async throws {
        let document = try SwiftMarkdownParser().parse("$x$")
        let url = try #require(URL(string: "javascript:alert(1)"))
        let options = HTMLRenderOptions(
            katexConfiguration: KaTeXConfiguration(assetSource: .custom(baseURL: url))
        )

        await #expect(throws: HTMLRenderingError.self) {
            try await HTMLRenderer(options: options).renderDocument(document)
        }
    }

    @Test("Encodes configuration without creating executable markup")
    func safelyEncodesConfiguration() async throws {
        let attack = "</script><script>alert('configuration')</script>"
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                fontFamily: attack,
                customCSS: attack
            )
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(!html.contains(attack))
        #expect(html.contains("\\u003C\\/script\\u003E\\u003Cscript\\u003E"))
    }

    @Test("Surfaces unavailable bundled assets through the document interface")
    func unavailableBundledAsset() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(assetSource: .bundled)
        )
        let renderer = HTMLRenderer(
            options: options,
            assetLoader: MissingBrowserAssetLoader()
        )

        await #expect(throws: HTMLRenderingError.self) {
            try await renderer.renderDocument(document)
        }
    }
}

private struct MissingBrowserAssetLoader: BrowserAssetLoading {
    func data(named name: String) throws -> Data {
        throw HTMLRenderingError.bundledAssetUnavailable(name)
    }
}

private extension String {
    func occurrences(of value: String) -> Int {
        components(separatedBy: value).count - 1
    }
}
