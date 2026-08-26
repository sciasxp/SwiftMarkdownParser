import SwiftUI
import Testing
@testable import SwiftMarkdownParser

@Suite("SwiftUI output seam")
@MainActor
struct SwiftUIRendererTests {
    @Test(
        "Renders representative documents through the document interface",
        arguments: [
            "Plain paragraph with *emphasis* and **strength**.",
            "# Heading\n\n> Quote\n\n- One\n- Two",
            "- [x] Complete\n- [ ] Pending",
            "| A | B |\n|---|---|\n| 1 | 2 |",
            "Inline $x^2$ and block math:\n\n$$\ny = mx + b\n$$",
            "```mermaid\ngraph TD\nA --> B\n```",
        ]
    )
    func representativeDocuments(markdown: String) async throws {
        let document = try SwiftMarkdownParser().parse(markdown)
        _ = try await SwiftUIRenderer().render(document)
    }

    @Test("Applies output-specific options at the document seam")
    func customOptions() async throws {
        let document = try SwiftMarkdownParser().parse("[Swift](guide/start) and ![Logo](logo.png)")
        let options = SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/"),
            styleConfiguration: .minimal,
            linkHandler: { _ in },
            imageHandler: { url in AnyView(Text(url.lastPathComponent)) }
        )

        _ = try await SwiftUIRenderer(options: options).render(document)
    }

    @Test("Rejects unsupported custom nodes atomically")
    func unsupportedNode() async {
        let document = AST.DocumentNode(children: [UnsupportedSwiftUITestNode()])

        await #expect(throws: SwiftUIRenderingError.self) {
            _ = try await SwiftUIRenderer().render(document)
        }
    }

    @Test("Renders a complete mixed document")
    func completeDocument() async throws {
        let markdown = """
        # SwiftUI Markdown Renderer

        A **complete** document with [a link](https://swift.org), `code`, and a task.

        - [x] Parsed
        - [ ] Presented

        ```swift
        let answer = 42
        ```

        | Feature | State |
        |:--------|------:|
        | AST | Ready |
        """

        let document = try SwiftMarkdownParser().parse(markdown)
        _ = try await SwiftUIRenderer().render(document)
    }
}
