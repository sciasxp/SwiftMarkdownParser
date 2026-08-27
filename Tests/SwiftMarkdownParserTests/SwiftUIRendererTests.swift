import Foundation
import SwiftUI
import Testing
#if os(macOS)
import AppKit
#endif
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

        let rendered = try await SwiftUIRenderer(
            options: SwiftUIRenderOptions(richContentHandlers: handlers)
        ).render(document)

        #if os(macOS)
        let image = ImageRenderer(content: rendered.frame(width: 240, alignment: .leading))
        _ = try #require(image.cgImage)
        #endif

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

    @Test("Projects one accessible inline meaning through the native seam")
    func nativeInlineAccessibility() throws {
        let nodes: [any ASTNode] = [
            AST.TextNode(content: "Read "),
            AST.LinkNode(
                url: "javascript:alert(1)",
                children: [AST.StrongEmphasisNode(children: [AST.TextNode(content: "this")])]
            ),
            AST.ImageNode(url: "data:text/plain,unsafe", altText: " diagram"),
            AST.FootnoteReferenceNode(identifier: "source")
        ]

        let content = try NativeInlineProjection(
            options: SwiftUIRenderOptions(baseURL: URL(string: "https://example.com/docs/"))
        ).project(nodes)

        #expect(content.accessibilityText == "Read this diagram[source]")
    }

    @Test("Routes rich inline adapters through every native container")
    func richInlineAdaptersAcrossContainers() async throws {
        let recorder = RichContentRecorder()
        let handlers = SwiftUIRichContentHandlers(
            inlineMath: { node in
                recorder.record("math:\(node.content)")
                return AnyView(Text(node.content))
            },
            htmlInline: { node in
                recorder.record("html:\(node.content)")
                return AnyView(Text(node.content))
            }
        )
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [AST.InlineMathNode(content: "paragraph")]),
            AST.HeadingNode(level: 2, children: [AST.HTMLInlineNode(content: "heading")]),
            AST.GFMTableNode(
                rows: [AST.GFMTableRowNode(
                    cells: [AST.GFMTableCellNode(
                        children: [AST.InlineMathNode(content: "table")],
                        isHeader: false
                    )],
                    isHeader: false
                )],
                alignments: [.left]
            ),
            AST.GFMTaskListItemNode(
                isChecked: true,
                children: [AST.HTMLInlineNode(content: "task")]
            )
        ])

        _ = try await SwiftUIRenderer(
            options: SwiftUIRenderOptions(richContentHandlers: handlers)
        ).render(document)

        #expect(recorder.values == [
            "math:paragraph",
            "html:heading",
            "math:table",
            "html:task"
        ])
    }

    @Test("Routes inline images through every native container")
    func inlineImagesAcrossContainers() async throws {
        let recorder = URLRecorder()
        let image: @Sendable (String) -> AST.ImageNode = { name in
            AST.ImageNode(url: "images/\(name).png", altText: name)
        }
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [image("paragraph")]),
            AST.HeadingNode(level: 2, children: [image("heading")]),
            AST.GFMTableNode(
                rows: [AST.GFMTableRowNode(
                    cells: [AST.GFMTableCellNode(children: [image("table")], isHeader: false)],
                    isHeader: false
                )],
                alignments: [.left]
            ),
            AST.GFMTaskListItemNode(isChecked: false, children: [image("task")])
        ])

        _ = try await SwiftUIRenderer(options: SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/"),
            imageHandler: { url in
                recorder.record(url)
                return AnyView(Text(url.lastPathComponent))
            }
        )).render(document)

        #expect(recorder.urls.map(\.lastPathComponent) == [
            "paragraph.png", "heading.png", "table.png", "task.png"
        ])
    }

    @Test("Validates the complete inline tree before invoking adapters")
    func inlineFailureIsAtomic() {
        let recorder = RichContentRecorder()
        let projection = NativeInlineProjection(options: SwiftUIRenderOptions(
            richContentHandlers: SwiftUIRichContentHandlers(
                inlineMath: { node in
                    recorder.record(node.content)
                    return AnyView(Text(node.content))
                }
            )
        ))
        let nodes: [any ASTNode] = [
            AST.StrongEmphasisNode(children: [
                AST.InlineMathNode(content: "must-not-run"),
                UnsupportedSwiftUITestNode()
            ])
        ]

        #expect(throws: SwiftUIRenderingError.self) {
            _ = try projection.project(nodes)
        }
        #expect(recorder.values.isEmpty)
    }

    #if os(macOS)
    @Test("Adapts native containers to width and accessibility text sizes")
    func adaptiveNativePresentation() async throws {
        let markdown = """
        > A quoted explanation that remains readable without spending the narrow viewport on decoration.

        7. A numbered item with enough content to exercise the adaptive marker layout.

        - [x] A completed task with a descriptive label.

        | Capability | Native behavior | Status |
        |:-----------|:----------------|-------:|
        | Tables | Become labeled rows when a grid no longer fits | Ready |
        | Type | Honors accessibility Dynamic Type sizes | Ready |

        A claim with a note[^source].

        [^source]: Supporting evidence that can move below its identifier.
        """
        let document = try SwiftMarkdownParser().parse(markdown)
        let content = try await SwiftUIRenderer().render(document)

        let wideRenderer = ImageRenderer(content:
            content
                .frame(width: 720, alignment: .leading)
                .padding(12)
                .background(.white)
        )
        let narrowRenderer = ImageRenderer(content:
            content
                .frame(width: 240, alignment: .leading)
                .padding(12)
                .background(.white)
        )
        let accessibilityRenderer = ImageRenderer(content:
            content
                .environment(\.dynamicTypeSize, .accessibility3)
                .frame(width: 720, alignment: .leading)
                .padding(12)
                .background(.white)
        )

        let wide = try #require(wideRenderer.cgImage)
        let narrow = try #require(narrowRenderer.cgImage)
        let accessibility = try #require(accessibilityRenderer.cgImage)
        #expect(wide.width == 744)
        #expect(narrow.width == 264)
        #expect(accessibility.width == 744)
        #expect(narrow.height > wide.height)
        #expect(accessibility.height > wide.height)

        if let output = ProcessInfo.processInfo.environment["SWIFTMARKDOWNPARSER_ADAPTIVE_RENDER_OUTPUT"] {
            let representation = NSBitmapImageRep(cgImage: accessibility)
            let data = try #require(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }

    @Test("Materializes wrapping mixed inline content into pixels")
    func materializesMixedInlineContent() throws {
        let projection = NativeInlineProjection(options: SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/"),
            richContentHandlers: SwiftUIRichContentHandlers(
                inlineMath: { node in
                    AnyView(
                        Text(node.content)
                            .padding(.horizontal, 4)
                            .background(.yellow.opacity(0.35), in: Capsule())
                    )
                },
                htmlInline: { node in
                    AnyView(
                        Text(node.content)
                            .padding(.horizontal, 4)
                            .background(.mint.opacity(0.35), in: Capsule())
                    )
                }
            ),
            imageHandler: { url in
                AnyView(
                    Text(url.deletingPathExtension().lastPathComponent.uppercased())
                        .padding(.horizontal, 4)
                        .background(.blue.opacity(0.2), in: Capsule())
                )
            }
        ))
        let content = try projection.project([
            AST.TextNode(content: "A long native inline flow with "),
            AST.StrongEmphasisNode(children: [AST.TextNode(content: "formatting")]),
            AST.TextNode(content: ", "),
            AST.InlineMathNode(content: "x²"),
            AST.TextNode(content: ", an "),
            AST.ImageNode(url: "images/icon.png", altText: "icon"),
            AST.TextNode(content: ", and "),
            AST.HTMLInlineNode(content: "<kbd>K</kbd>"),
            AST.TextNode(content: " that must wrap without losing order.")
        ])

        let renderer = ImageRenderer(content:
            content
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 260, alignment: .leading)
                .padding(12)
                .background(.white)
        )
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == 568)
        #expect(image.height > 80)
        #expect(content.accessibilityText == "A long native inline flow with formatting, x², an icon, and <kbd>K</kbd> that must wrap without losing order.")

        if let output = ProcessInfo.processInfo.environment["SWIFTMARKDOWNPARSER_RENDER_OUTPUT"] {
            let representation = NSBitmapImageRep(cgImage: image)
            let data = try #require(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }
    #endif

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
