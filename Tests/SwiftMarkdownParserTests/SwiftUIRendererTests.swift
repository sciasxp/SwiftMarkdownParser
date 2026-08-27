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

@available(iOS 17.0, macOS 14.0, *)
private extension SwiftUIRichContentRequest {
    var testDescription: String {
        switch self {
        case let .image(node, source):
            "image:\(node.altText):\(source.lastPathComponent)"
        case let .mermaid(node, configuration):
            "mermaid:\(configuration.theme.rawValue):\(node.content)"
        case let .mathBlock(node):
            "math-block:\(node.content)"
        case let .inlineMath(node):
            "math-inline:\(node.content)"
        case let .htmlBlock(node):
            "html-block:\(node.content)"
        case let .htmlInline(node):
            "html-inline:\(node.content)"
        }
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
            richContentAdapter: SwiftUIRichContentAdapter { request in
                guard case let .image(_, source) = request else { return nil }
                return AnyView(Text(source.lastPathComponent))
            },
            linkHandler: { _ in }
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

    @Test("Routes every rich request through one host adapter and honors decline")
    func richContentAdapters() async throws {
        let recorder = RichContentRecorder()
        let adapter = SwiftUIRichContentAdapter { request in
            let description = request.testDescription
            recorder.record(description)
            if case .htmlBlock = request {
                return nil
            }
            return AnyView(Text(description))
        }
        let document = AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "graph TD; A-->B"),
            AST.MathBlockNode(content: "x^2"),
            AST.InlineMathNode(content: "x"),
            AST.HTMLBlockNode(content: "<aside>Note</aside>"),
            AST.HTMLInlineNode(content: "<kbd>K</kbd>"),
            AST.ImageNode(url: "https://example.com/logo.png", altText: "Logo")
        ])

        let rendered = try await SwiftUIRenderer(
            options: SwiftUIRenderOptions(
                mermaidConfiguration: MermaidConfiguration(theme: .dark),
                richContentAdapter: adapter
            )
        ).render(document)

        #if os(macOS)
        let image = ImageRenderer(content: rendered.frame(width: 240, alignment: .leading))
        _ = try #require(image.cgImage)
        #endif

        #expect(recorder.values == [
            "mermaid:dark:graph TD; A-->B",
            "math-block:x^2",
            "math-inline:x",
            "html-block:<aside>Note</aside>",
            "html-inline:<kbd>K</kbd>",
            "image:Logo:logo.png"
        ])
    }

    @Test("Resolves image destinations before invoking the host adapter")
    func resolvesImageDestination() async throws {
        let document = try SwiftMarkdownParser().parse("![Logo](images/logo.png)")
        let recorder = URLRecorder()
        let options = SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/")!,
            richContentAdapter: SwiftUIRichContentAdapter { request in
                guard case let .image(_, source) = request else { return nil }
                recorder.record(source)
                return AnyView(EmptyView())
            }
        )

        _ = try await SwiftUIRenderer(options: options).render(document)

        #expect(recorder.urls == [URL(string: "https://example.com/docs/images/logo.png")!])
    }

    @Test("Invokes the image adapter at most once when it declines")
    func imageAdapterDecline() async throws {
        let recorder = RichContentRecorder()
        let document = try SwiftMarkdownParser().parse("![Logo](images/logo.png)")
        let options = SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/"),
            richContentAdapter: SwiftUIRichContentAdapter { request in
                recorder.record(request.testDescription)
                return nil
            }
        )

        _ = try await SwiftUIRenderer(options: options).render(document)

        #expect(recorder.values == ["image:Logo:logo.png"])
    }

    @Test(
        "Does not send invalid image destinations to the host adapter",
        arguments: ["javascript:alert(1)", "data:text/plain,unsafe", "   "]
    )
    func rejectsInvalidImageDestination(destination: String) async throws {
        let document = AST.DocumentNode(children: [
            AST.ImageNode(url: destination, altText: "Unavailable", title: nil)
        ])
        let recorder = URLRecorder()
        let options = SwiftUIRenderOptions(
            richContentAdapter: SwiftUIRichContentAdapter { request in
                guard case let .image(_, source) = request else { return nil }
                recorder.record(source)
                return AnyView(EmptyView())
            }
        )

        _ = try await SwiftUIRenderer(options: options).render(document)

        #expect(recorder.urls.isEmpty)
    }

    @Test("Ordered-list markers honor the document start number")
    func orderedListStartNumber() {
        let semantics = NativePresentationSemantics()
        #expect(semantics.orderedListMarker(startNumber: 7, index: 0) == "7.")
        #expect(semantics.orderedListMarker(startNumber: 7, index: 2) == "9.")
        #expect(semantics.orderedListMarker(startNumber: nil, index: 1) == "2.")
    }

    @Test("Normalizes table columns, headers, and rows during document projection")
    func normalizesNativeTableMeaning() throws {
        let table = try projectedTable(AST.GFMTableNode(
            rows: [
                AST.GFMTableRowNode(
                    cells: [
                        AST.GFMTableCellNode(content: "Name", isHeader: false, alignment: .right),
                        AST.GFMTableCellNode(content: "State", isHeader: false, alignment: .left),
                    ],
                    isHeader: true
                ),
                AST.GFMTableRowNode(
                    cells: [
                        AST.GFMTableCellNode(content: "Parser", isHeader: true, alignment: .right),
                        AST.GFMTableCellNode(content: "Ready", isHeader: true, alignment: .left),
                        AST.GFMTableCellNode(content: "Extra", isHeader: true, alignment: .center),
                    ],
                    isHeader: false
                ),
                AST.GFMTableRowNode(
                    cells: [AST.GFMTableCellNode(content: "Later", isHeader: true)],
                    isHeader: true
                ),
            ],
            alignments: [.center]
        ))

        #expect(table.columns.map(\.index) == [0, 1, 2])
        #expect(table.columns.map(\.alignment) == [.center, .none, .none])
        #expect(table.columns.map { $0.header?.accessibilityText } == ["Name", "State", nil])
        #expect(table.rows.count == 2)
        #expect(table.rows[0].cells.map(\.columnIndex) == [0, 1, 2])
        #expect(table.rows[0].cells.map(\.content.accessibilityText) == ["Parser", "Ready", "Extra"])
        #expect(table.rows[1].cells.map(\.content.accessibilityText) == ["Later"])
    }

    @Test("Keeps headerless and header-only table plans explicit")
    func normalizesNativeTableEdgeShapes() throws {
        let headerless = try projectedTable(AST.GFMTableNode(
            rows: [
                AST.GFMTableRowNode(
                    cells: [AST.GFMTableCellNode(
                        content: "Value",
                        isHeader: true,
                        alignment: .right
                    )],
                    isHeader: false
                ),
                AST.GFMTableRowNode(
                    cells: [AST.GFMTableCellNode(content: "Not a header", isHeader: true)],
                    isHeader: true
                ),
            ],
            alignments: []
        ))
        let headerOnly = try projectedTable(AST.GFMTableNode(
            rows: [AST.GFMTableRowNode(
                cells: [AST.GFMTableCellNode(content: "Heading", isHeader: false)],
                isHeader: true
            )],
            alignments: [.right]
        ))

        #expect(headerless.columns.count == 1)
        #expect(headerless.columns[0].header == nil)
        #expect(headerless.columns[0].alignment == .none)
        #expect(headerless.rows.count == 2)
        #expect(headerless.rows[0].cells[0].content.accessibilityText == "Value")
        #expect(headerless.rows[1].cells[0].content.accessibilityText == "Not a header")

        #expect(headerOnly.columns.count == 1)
        #expect(headerOnly.columns[0].header?.accessibilityText == "Heading")
        #expect(headerOnly.columns[0].alignment == .right)
        #expect(headerOnly.rows.isEmpty)
    }

    @Test("Owns Dynamic Type policy for every adaptive label/content role")
    func adaptiveLabelContentRolePolicy() {
        let style = SwiftUIStyleConfiguration.github

        #expect(!NativeAdaptiveLabelContentRole.listMarker.metrics(
            style: style,
            accessibilitySize: true
        ).prefersVertical)
        #expect(!NativeAdaptiveLabelContentRole.taskStatus.metrics(
            style: style,
            accessibilitySize: true
        ).prefersVertical)
        #expect(NativeAdaptiveLabelContentRole.footnoteIdentifier.metrics(
            style: style,
            accessibilitySize: true
        ).prefersVertical)
        #expect(NativeAdaptiveLabelContentRole.mermaidTitle.metrics(
            style: style,
            accessibilitySize: true
        ).prefersVertical)
        #expect(NativeAdaptiveLabelContentRole.tableField.metrics(
            style: style,
            accessibilitySize: false
        ).prefersVertical)
    }

    @Test("Chooses the label/content axis at a finite deterministic threshold")
    func adaptiveLabelContentAxisThreshold() {
        let metrics = NativeAdaptiveLabelContentGeometry.Metrics(
            horizontalSpacing: 8,
            verticalSpacing: 4,
            minimumContentWidth: 32,
            prefersVertical: false,
            alignment: .firstBaseline
        )

        #expect(NativeAdaptiveLabelContentGeometry.axis(
            availableWidth: 60,
            intrinsicLabelWidth: 20,
            metrics: metrics
        ) == .horizontal)
        #expect(NativeAdaptiveLabelContentGeometry.axis(
            availableWidth: 59,
            intrinsicLabelWidth: 20,
            metrics: metrics
        ) == .vertical)
        #expect(NativeAdaptiveLabelContentGeometry.axis(
            availableWidth: 0,
            intrinsicLabelWidth: 20,
            metrics: metrics
        ) == .vertical)
        #expect(NativeAdaptiveLabelContentGeometry.axis(
            availableWidth: nil,
            intrinsicLabelWidth: 20,
            metrics: metrics
        ) == .horizontal)
        #expect(NativeAdaptiveLabelContentGeometry.normalizedWidth(-10) == 0)
        #expect(NativeAdaptiveLabelContentGeometry.normalizedWidth(.infinity) == nil)
        #expect(NativeAdaptiveLabelContentGeometry.normalizedWidth(.nan) == nil)
    }

    @Test("Aligns baselines and mirrors horizontal label/content geometry in RTL")
    func adaptiveLabelContentBaselineAndRTL() {
        let metrics = NativeAdaptiveLabelContentGeometry.Metrics(
            horizontalSpacing: 8,
            verticalSpacing: 4,
            minimumContentWidth: 0,
            prefersVertical: false,
            alignment: .firstBaseline
        )
        let plan = NativeAdaptiveLabelContentGeometry.plan(
            axis: .horizontal,
            availableWidth: 100,
            label: .init(size: CGSize(width: 20, height: 10), firstBaseline: 8),
            content: .init(size: CGSize(width: 30, height: 20), firstBaseline: 12),
            metrics: metrics,
            layoutDirection: .rightToLeft
        )

        #expect(plan.size == CGSize(width: 100, height: 20))
        #expect(plan.labelFrame == CGRect(x: 80, y: 4, width: 20, height: 10))
        #expect(plan.contentFrame == CGRect(x: 42, y: 0, width: 30, height: 20))
    }

    @Test("Keeps oversized and unconstrained label/content geometry finite")
    func adaptiveLabelContentFiniteGeometry() {
        let metrics = NativeAdaptiveLabelContentGeometry.Metrics(
            horizontalSpacing: 8,
            verticalSpacing: 4,
            minimumContentWidth: 32,
            prefersVertical: false,
            alignment: .top
        )
        let label = NativeAdaptiveLabelContentGeometry.Measurement(
            size: CGSize(width: 80, height: 10),
            firstBaseline: nil
        )
        let content = NativeAdaptiveLabelContentGeometry.Measurement(
            size: CGSize(width: 40, height: 20),
            firstBaseline: nil
        )
        let constrained = NativeAdaptiveLabelContentGeometry.plan(
            axis: .vertical,
            availableWidth: 30,
            label: label,
            content: content,
            metrics: metrics,
            layoutDirection: .rightToLeft
        )
        let unconstrained = NativeAdaptiveLabelContentGeometry.plan(
            axis: .horizontal,
            availableWidth: .infinity,
            label: label,
            content: content,
            metrics: metrics,
            layoutDirection: .leftToRight
        )

        #expect(constrained.size == CGSize(width: 30, height: 34))
        #expect(constrained.labelFrame.width == 30)
        #expect(constrained.contentFrame.width == 30)
        #expect(unconstrained.size == CGSize(width: 128, height: 20))
        #expect(unconstrained.size.width.isFinite)
        #expect(unconstrained.size.height.isFinite)
    }

    @Test("Owns unique identity and preserves it through view transformations")
    func nativeViewMaterializationIdentity() throws {
        let materializer = NativeViewMaterializer()
        let rowIdentity = materializer.identity()
        let first = materializer.materialize(Text("First"))
        let transformed = materializer.transform(first) { content in
            content.fontWeight(.bold).foregroundStyle(.blue)
        }
        let second = materializer.materialize(Text("Second"))

        #expect(rowIdentity < first.id)
        #expect(first.id == transformed.id)
        #expect(first.id < second.id)

        #if os(macOS)
        let renderer = ImageRenderer(content: transformed)
        _ = try #require(renderer.cgImage)
        #endif
    }

    @Test("Localizes every native semantic role from the package bundle")
    func nativeSemanticLocalization() {
        let semantics = NativePresentationSemantics()
        let cases: [(NativePresentationSemantics.Message, String)] = [
            (.sectionDivider, "Divisor de seção"),
            (.codeBlock(language: nil), "Bloco de código"),
            (.codeBlock(language: "Swift"), "Bloco de código em Swift"),
            (.footnote(identifier: "fonte"), "Nota de rodapé fonte"),
            (.task(isCompleted: true, content: "Validar"), "Tarefa concluída: Validar"),
            (.task(isCompleted: false, content: "Validar"), "Tarefa incompleta: Validar"),
            (.table, "Tabela"),
            (.tableHeader(content: "Estado"), "Cabeçalho: Estado"),
            (.mermaidTitle, "Diagrama Mermaid"),
            (.mermaidDiagram(type: "flowchart"), "Diagrama Mermaid: flowchart"),
            (.mermaidDiagram(type: nil), "Diagrama Mermaid: tipo desconhecido"),
            (.inlineMath(content: "x²"), "Matemática: x²"),
            (.htmlBlock, "Conteúdo HTML"),
            (.htmlInline(content: "<kbd>K</kbd>"), "HTML: <kbd>K</kbd>"),
            (.loadingImage(alternativeText: "Capa"), "Carregando imagem: Capa"),
            (.mathExpression, "Expressão matemática"),
            (
                .unsupportedNodeType("custom"),
                "Tipo de nó da AST não compatível: custom"
            ),
        ]

        for (message, expected) in cases {
            var resource = semantics.localized(message)
            resource.locale = Locale(identifier: "pt-BR")
            #expect(String(localized: resource) == expected)
        }
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

    @Test("Routes rich inline adapters through every native container")
    func richInlineAdaptersAcrossContainers() async throws {
        let recorder = RichContentRecorder()
        let adapter = SwiftUIRichContentAdapter { request in
            switch request {
            case let .inlineMath(node):
                recorder.record("math:\(node.content)")
                return AnyView(Text(node.content))
            case let .htmlInline(node):
                recorder.record("html:\(node.content)")
                return AnyView(Text(node.content))
            case .image, .mermaid, .mathBlock, .htmlBlock:
                return nil
            }
        }
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
            options: SwiftUIRenderOptions(richContentAdapter: adapter)
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
            richContentAdapter: SwiftUIRichContentAdapter { request in
                guard case let .image(_, source) = request else { return nil }
                recorder.record(source)
                return AnyView(Text(source.lastPathComponent))
            }
        )).render(document)

        #expect(recorder.urls.map(\.lastPathComponent) == [
            "paragraph.png", "heading.png", "table.png", "task.png"
        ])
    }

    @Test("Validates the complete inline tree before invoking adapters")
    func inlineFailureIsAtomic() async {
        let recorder = RichContentRecorder()
        let options = SwiftUIRenderOptions(
            richContentAdapter: SwiftUIRichContentAdapter { request in
                if case let .inlineMath(node) = request {
                    recorder.record(node.content)
                    return AnyView(Text(node.content))
                }
                return nil
            }
        )
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [
                AST.StrongEmphasisNode(children: [
                    AST.InlineMathNode(content: "must-not-run"),
                    UnsupportedSwiftUITestNode()
                ])
            ])
        ])

        await #expect(throws: SwiftUIRenderingError.self) {
            _ = try await SwiftUIRenderer(options: options).render(document)
        }
        #expect(recorder.values.isEmpty)
    }

    @Test("Validates the complete document before invoking adapters")
    func documentFailurePreventsEarlierAdapterEffects() async {
        let recorder = RichContentRecorder()
        let options = SwiftUIRenderOptions(
            richContentAdapter: SwiftUIRichContentAdapter { request in
                recorder.record(request.testDescription)
                return AnyView(Text(request.testDescription))
            }
        )
        let document = AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "flowchart LR; A-->B"),
            UnsupportedSwiftUITestNode()
        ])

        await #expect(throws: SwiftUIRenderingError.self) {
            _ = try await SwiftUIRenderer(options: options).render(document)
        }
        #expect(recorder.values.isEmpty)
    }

    @Test("Finds nested document failures before invoking earlier adapters")
    func nestedDocumentFailurePreventsAdapterEffects() async {
        let recorder = RichContentRecorder()
        let options = SwiftUIRenderOptions(
            richContentAdapter: SwiftUIRichContentAdapter { request in
                recorder.record(request.testDescription)
                return AnyView(Text(request.testDescription))
            }
        )
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [AST.InlineMathNode(content: "must-not-run")]),
            AST.BlockQuoteNode(children: [
                AST.ListNode(isOrdered: false, items: [
                    AST.ListItemNode(children: [
                        AST.ParagraphNode(children: [
                            AST.StrongEmphasisNode(children: [
                                UnsupportedSwiftUITestNode()
                            ])
                        ])
                    ])
                ])
            ])
        ])

        await #expect(throws: SwiftUIRenderingError.self) {
            _ = try await SwiftUIRenderer(options: options).render(document)
        }
        #expect(recorder.values.isEmpty)
    }

    @Test("Reports the first unsupported node in depth-first document order")
    func documentFailureOrderIsDepthFirst() async {
        let document = AST.DocumentNode(children: [
            AST.BlockQuoteNode(children: [
                AST.ListNode(isOrdered: false, items: [
                    AST.ListItemNode(children: [
                        AST.ParagraphNode(children: [
                            UnsupportedSwiftUITestNode("first-depth-first")
                        ])
                    ])
                ])
            ]),
            UnsupportedSwiftUITestNode("second-top-level")
        ])

        do {
            _ = try await SwiftUIRenderer().render(document)
            Issue.record("Expected the first unsupported node to fail projection")
        } catch let error as SwiftUIRenderingError {
            switch error {
            case let .unsupportedNodeType(type):
                #expect(type.rawValue == "first-depth-first")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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

        ```mermaid
        flowchart LR
            Source --> Native
        ```

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

        if let output = ProcessInfo.processInfo.environment[
            "SWIFTMARKDOWNPARSER_ADAPTIVE_WIDE_RENDER_OUTPUT"
        ] {
            let representation = NSBitmapImageRep(cgImage: wide)
            let data = try #require(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
        if let output = ProcessInfo.processInfo.environment["SWIFTMARKDOWNPARSER_ADAPTIVE_RENDER_OUTPUT"] {
            let representation = NSBitmapImageRep(cgImage: accessibility)
            let data = try #require(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }

    @Test("Does not reinvoke rich adapters across adaptive recomposition")
    func adaptiveRecompositionPreservesRichAdapterEffects() async throws {
        let recorder = RichContentRecorder()
        let document = AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "flowchart LR; Source-->Native")
        ])
        let content = try await SwiftUIRenderer(options: SwiftUIRenderOptions(
            richContentAdapter: SwiftUIRichContentAdapter { request in
                recorder.record(request.testDescription)
                return AnyView(Text(request.testDescription))
            }
        )).render(document)
        #expect(recorder.values.count == 1)

        let wide = ImageRenderer(content:
            content.frame(width: 720, alignment: .leading)
        )
        let narrow = ImageRenderer(content:
            content.frame(width: 180, alignment: .leading)
        )
        let accessibility = ImageRenderer(content:
            content
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(width: 320, alignment: .leading)
        )

        _ = try #require(wide.cgImage)
        _ = try #require(narrow.cgImage)
        _ = try #require(accessibility.cgImage)
        #expect(recorder.values.count == 1)
    }

    @Test("Materializes a reusable rich table header exactly once")
    func tableHeaderMaterializationIsSingleShot() async throws {
        let recorder = RichContentRecorder()
        let document = AST.DocumentNode(children: [
            AST.GFMTableNode(
                rows: [
                    AST.GFMTableRowNode(
                        cells: [AST.GFMTableCellNode(
                            children: [AST.InlineMathNode(content: "Capability")],
                            isHeader: true
                        )],
                        isHeader: true
                    ),
                    AST.GFMTableRowNode(
                        cells: [AST.GFMTableCellNode(content: "Native", isHeader: false)],
                        isHeader: false
                    ),
                    AST.GFMTableRowNode(
                        cells: [AST.GFMTableCellNode(content: "Adaptive", isHeader: false)],
                        isHeader: false
                    ),
                ],
                alignments: [.left]
            )
        ])
        let content = try await SwiftUIRenderer(options: SwiftUIRenderOptions(
            richContentAdapter: SwiftUIRichContentAdapter { request in
                guard case let .inlineMath(node) = request else { return nil }
                recorder.record(node.content)
                return AnyView(Text(node.content))
            }
        )).render(document)

        #expect(recorder.values == ["Capability"])

        _ = try #require(ImageRenderer(content:
            content.frame(width: 480, alignment: .leading)
        ).cgImage)
        _ = try #require(ImageRenderer(content:
            content.frame(width: 120, alignment: .leading)
        ).cgImage)
        _ = try #require(ImageRenderer(content:
            content
                .environment(\.dynamicTypeSize, .accessibility3)
                .frame(width: 320, alignment: .leading)
        ).cgImage)

        #expect(recorder.values == ["Capability"])
    }

    @Test("Materializes package-localized native fallback text")
    func materializesLocalizedNativeFallback() async throws {
        let document = AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "flowchart LR; A-->B")
        ])
        let content = try await SwiftUIRenderer().render(document)
        let renderer = ImageRenderer(content:
            content
                .environment(\.locale, Locale(identifier: "pt-BR"))
                .frame(width: 320, alignment: .leading)
                .padding(12)
                .background(.white)
        )
        renderer.scale = 2

        let image = try #require(renderer.cgImage)
        #expect(image.width == 688)
        #expect(image.height > 80)

        if let output = ProcessInfo.processInfo.environment[
            "SWIFTMARKDOWNPARSER_LOCALIZED_RENDER_OUTPUT"
        ] {
            let representation = NSBitmapImageRep(cgImage: image)
            let data = try #require(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }

    @Test("Materializes Mermaid source as visible fallback content")
    func materializesVisibleMermaidSource() async throws {
        let first = try await SwiftUIRenderer().render(AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "flowchart LR; Alpha-->Beta")
        ]))
        let second = try await SwiftUIRenderer().render(AST.DocumentNode(children: [
            AST.MermaidDiagramNode(content: "flowchart LR; Gamma-->Delta")
        ]))
        let firstImage = try #require(ImageRenderer(content:
            first.frame(width: 320, alignment: .leading)
        ).cgImage)
        let secondImage = try #require(ImageRenderer(content:
            second.frame(width: 320, alignment: .leading)
        ).cgImage)
        let firstData = try #require(NSBitmapImageRep(cgImage: firstImage).representation(
            using: .png,
            properties: [:]
        ))
        let secondData = try #require(NSBitmapImageRep(cgImage: secondImage).representation(
            using: .png,
            properties: [:]
        ))

        #expect(firstData != secondData)
    }

    @Test("Materializes wrapping mixed inline content into pixels")
    func materializesMixedInlineContent() async throws {
        let options = SwiftUIRenderOptions(
            baseURL: URL(string: "https://example.com/docs/"),
            richContentAdapter: SwiftUIRichContentAdapter { request in
                switch request {
                case let .inlineMath(node):
                    AnyView(
                        Text(node.content)
                            .padding(.horizontal, 4)
                            .background(.yellow.opacity(0.35), in: Capsule())
                    )
                case let .htmlInline(node):
                    AnyView(
                        Text(node.content)
                            .padding(.horizontal, 4)
                            .background(.mint.opacity(0.35), in: Capsule())
                    )
                case let .image(_, source):
                    AnyView(
                        Text(source.deletingPathExtension().lastPathComponent.uppercased())
                            .padding(.horizontal, 4)
                            .background(.blue.opacity(0.2), in: Capsule())
                    )
                case .mermaid, .mathBlock, .htmlBlock:
                    nil
                }
            }
        )
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [
                AST.TextNode(content: "A long native inline flow with "),
                AST.StrongEmphasisNode(children: [AST.TextNode(content: "formatting")]),
                AST.TextNode(content: ", "),
                AST.InlineMathNode(content: "x²"),
                AST.TextNode(content: ", an "),
                AST.ImageNode(url: "images/icon.png", altText: "icon"),
                AST.TextNode(content: ", and "),
                AST.HTMLInlineNode(content: "<kbd>K</kbd>"),
                AST.TextNode(content: ", plus "),
                AST.LinkNode(
                    url: "https://example.com/fallback",
                    children: [AST.ImageNode(url: "data:text/plain,unsafe", altText: "fallback")]
                ),
                AST.TextNode(content: " that must wrap without losing order.")
            ])
        ])
        let content = try await SwiftUIRenderer(options: options).render(document)

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

        let runs = NativePresentationSemantics().codeRuns(source: source, tokens: tokens)

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

    private func projectedTable(
        _ table: AST.GFMTableNode
    ) throws -> NativeDocumentProjection.Table {
        let plan = try NativeDocumentProjection(options: .init()).project(
            AST.DocumentNode(children: [table])
        )
        guard let first = plan.blocks.first,
              case let .table(projected) = first else {
            throw ProjectedTableTestError.missingTable
        }
        return projected
    }
}

private enum ProjectedTableTestError: Error {
    case missingTable
}
