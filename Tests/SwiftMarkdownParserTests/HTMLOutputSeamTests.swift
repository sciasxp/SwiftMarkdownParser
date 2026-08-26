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
        #expect(head.contains("mermaid.initialize"))
        #expect(!body.contains("<link rel=\"stylesheet\""))
        #expect(html.contains("<html lang=\"pt-BR\">"))
        #expect(html.contains("<title>Math &amp; Diagrams</title>"))
    }

    @Test(
        "Owns Mermaid theme generation",
        arguments: [
            (MermaidConfiguration.Theme.dark, "theme: 'dark'"),
            (.forest, "theme: 'forest'"),
            (.neutral, "theme: 'neutral'"),
            (.base, "theme: 'base'"),
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
        let configuration = KaTeXConfiguration(
            renderMode: .custom(url: "https://assets.example/katex")
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
}
