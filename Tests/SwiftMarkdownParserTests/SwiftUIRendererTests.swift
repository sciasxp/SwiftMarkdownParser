import Foundation
import SwiftUI
import Testing
@testable import SwiftMarkdownParser

private final class URLRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    var urls: [URL] {
        lock.withLock { storage }
    }

    func record(_ url: URL) {
        lock.withLock { storage.append(url) }
    }
}

private final class RichContentRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.withLock { storage }
    }

    func record(_ value: String) {
        lock.withLock { storage.append(value) }
    }
}

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
            syntaxHighlightingTheme: .xcode,
            linkHandler: { _ in },
            imageHandler: { url in AnyView(Text(url.lastPathComponent)) }
        )

        _ = try await SwiftUIRenderer(options: options).render(document)
    }

    @Test("Renders supported and unsupported code languages with semantic fallback")
    func syntaxHighlightingFallback() async throws {
        let options = SwiftUIRenderOptions(syntaxHighlightingTheme: .xcode)
        let renderer = SwiftUIRenderer(options: options)

        _ = try await renderer.render(AST.DocumentNode(children: [
            AST.CodeBlockNode(content: "let answer = 42", language: "swift", isFenced: true),
            AST.CodeBlockNode(content: "opaque source", language: "unknown", isFenced: true)
        ]))
    }

    @Test("Routes rich nodes through host adapters")
    func richContentAdapters() async throws {
        let recorder = RichContentRecorder()
        let handlers = SwiftUIRichContentHandlers(
            mermaid: { node, _ in recorder.record("mermaid:\(node.content)"); return AnyView(EmptyView()) },
            mathBlock: { node in recorder.record("math-block:\(node.content)"); return AnyView(EmptyView()) },
            inlineMath: { node in recorder.record("math-inline:\(node.content)"); return AnyView(EmptyView()) },
            htmlBlock: { node in recorder.record("html-block:\(node.content)"); return AnyView(EmptyView()) },
            htmlInline: { node in recorder.record("html-inline:\(node.content)"); return AnyView(EmptyView()) }
        )
        let document = AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "graph TD; A-->B"),
            AST.MathBlockNode(content: "x^2"),
            AST.InlineMathNode(content: "x"),
            AST.HTMLBlockNode(content: "<aside>Note</aside>"),
            AST.HTMLInlineNode(content: "<kbd>K</kbd>")
        ])

        _ = try await SwiftUIRenderer(
            options: SwiftUIRenderOptions(richContentHandlers: handlers)
        ).render(document)

        #expect(recorder.values == [
            "mermaid:graph TD; A-->B",
            "math-block:x^2",
            "math-inline:x",
            "html-block:<aside>Note</aside>",
            "html-inline:<kbd>K</kbd>"
        ])
    }

    @Test("Resolves image destinations before invoking the host handler")
    func resolvesImageDestination() async throws {
        let document = try SwiftMarkdownParser().parse("![Logo](images/logo.png)")
        let recorder = URLRecorder()
        let options = SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/")!,
            imageHandler: { url in
                recorder.record(url)
                return AnyView(EmptyView())
            }
        )

        _ = try await SwiftUIRenderer(options: options).render(document)

        #expect(recorder.urls == [URL(string: "https://example.com/docs/images/logo.png")!])
    }

    @Test("Does not send unsafe image destinations to the host handler")
    func rejectsUnsafeImageDestination() async throws {
        let document = AST.DocumentNode(children: [
            AST.ImageNode(url: "javascript:alert(1)", altText: "Unsafe", title: nil)
        ])
        let recorder = URLRecorder()
        let options = SwiftUIRenderOptions(imageHandler: { url in
            recorder.record(url)
            return AnyView(EmptyView())
        })

        _ = try await SwiftUIRenderer(options: options).render(document)

        #expect(recorder.urls.isEmpty)
    }

    @Test("Ordered-list markers honor the document start number")
    func orderedListStartNumber() {
        #expect(SwiftUIRenderSemantics.orderedListMarker(startNumber: 7, index: 0) == "7.")
        #expect(SwiftUIRenderSemantics.orderedListMarker(startNumber: 7, index: 2) == "9.")
        #expect(SwiftUIRenderSemantics.orderedListMarker(startNumber: nil, index: 1) == "2.")
    }

    @Test("Renders footnote references and definitions through the document seam")
    func footnotes() async throws {
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [
                AST.TextNode(content: "Claim"),
                AST.FootnoteReferenceNode(identifier: "source")
            ]),
            AST.FootnoteDefinitionNode(
                identifier: "source",
                children: [AST.ParagraphNode(children: [AST.TextNode(content: "Evidence")])]
            )
        ])

        _ = try await SwiftUIRenderer().render(document)
    }

    @Test("Projects formatted links into wrapping inline runs")
    func inlineRuns() throws {
        let nodes: [any ASTNode] = [
            AST.TextNode(content: "Read "),
            AST.LinkNode(
                url: "guide/start",
                children: [AST.StrongEmphasisNode(children: [AST.TextNode(content: "this")])]
            ),
            AST.TextNode(content: " now")
        ]

        let runs = try #require(
            SwiftUIRenderSemantics.inlineRuns(
                for: nodes,
                relativeTo: URL(string: "https://example.com/docs/")
            )
        )

        #expect(runs.map(\.text) == ["Read ", "this", " now"])
        #expect(runs[1].styles.contains(.strong))
        #expect(runs[1].link == URL(string: "https://example.com/docs/guide/start"))
    }

    @Test("Keeps flattened task-list inline content in one text flow")
    func taskListInlineFlow() throws {
        let document = try SwiftMarkdownParser().parse("- [x] Completed **task**")
        let list = try #require(document.children.first as? AST.ListNode)
        let task = try #require(list.items.first as? AST.GFMTaskListItemNode)
        let runs = try #require(
            SwiftUIRenderSemantics.inlineRuns(for: task.children, relativeTo: nil)
        )

        #expect(runs.map(\.text).joined() == "Completed task")
        #expect(runs.contains { $0.text == "task" && $0.styles.contains(.strong) })
    }

    @Test("Preserves unhighlighted gaps around semantic syntax tokens")
    func syntaxRunsPreserveSource() {
        let source = "let answer = 42"
        let keywordEnd = source.index(source.startIndex, offsetBy: 3)
        let numberStart = source.index(source.endIndex, offsetBy: -2)
        let tokens = [
            SyntaxToken(content: "let", tokenType: .keyword, range: source.startIndex..<keywordEnd),
            SyntaxToken(content: "42", tokenType: .number, range: numberStart..<source.endIndex)
        ]

        let runs = SwiftUIRenderSemantics.codeRuns(source: source, tokens: tokens)

        #expect(runs.map(\.text).joined() == source)
        #expect(runs.map(\.tokenType) == [.keyword, nil, .number])
    }

    @Test("Renders a thousand native blocks without truncation", .timeLimit(.minutes(1)))
    func largeNativeDocument() async throws {
        let children: [any ASTNode] = (0..<1_000).map { index in
            AST.ParagraphNode(children: [
                AST.TextNode(content: "Paragraph \(index) with "),
                AST.StrongEmphasisNode(children: [AST.TextNode(content: "formatting")])
            ])
        }

        _ = try await SwiftUIRenderer().render(AST.DocumentNode(children: children))
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
