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
        arguments: [
            "javascript:alert(1)",
            "data:text/plain,unsafe",
            "   ",
            "java\tscript:alert(1)",
            "da\nta:text/plain,unsafe"
        ]
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

    @Test(
        "Projects link and autolink text without a destination outside the allowlist",
        arguments: [
            "javascript:alert(1)",
            "java\tscript:alert(1)",
            "java\nscript:alert(1)",
            "\u{01}javascript:alert(1)",
            "vbscript:msgbox(1)",
            "file:///etc/passwd"
        ]
    )
    func projectLink_destinationOutsideAllowlist_dropsLink(destination: String) throws {
        let links = try projectedLinks([
            AST.LinkNode(url: destination, title: nil, children: [AST.TextNode(content: "link")]),
            AST.AutolinkNode(url: destination, text: "autolink")
        ])

        #expect(links.map(\.text) == ["linkautolink"])
        #expect(links.allSatisfy { $0.link == nil })
    }

    @Test func projectLink_relativeDestinationWithFileBase_resolvesAgainstBase() throws {
        let base = URL(fileURLWithPath: "/Users/reader/docs/", isDirectory: true)

        let links = try projectedLinks(
            [AST.LinkNode(url: "guide.md", title: nil, children: [AST.TextNode(content: "guide")])],
            baseURL: base
        )

        #expect(links.first?.link?.absoluteString == "file:///Users/reader/docs/guide.md")
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

    @Test("Native style owns Dynamic Type policy for every adaptive label/content role")
    func adaptiveLabelContentRolePolicy() {
        let style = NativePresentationStyle(.github)

        #expect(!style.list.markerMetrics.accessibility.prefersVertical)
        #expect(!style.task.statusMetrics.accessibility.prefersVertical)
        #expect(style.list.footnoteMetrics.accessibility.prefersVertical)
        #expect(style.codeBlock.titleMetrics.accessibility.prefersVertical)
        #expect(style.table.fieldMetrics.standard.prefersVertical)
    }

    @Test("Dark mode preserves every customization outside its deliberate palette")
    func darkModePreservesCustomStyle() {
        let source = distinctiveStyle()
        let dark = source.darkMode()
        let expectedPalette = SwiftUIStyleConfiguration().darkMode()
        let paletteFields: Set<String> = [
            "codeBackgroundColor",
            "blockQuoteBorderColor",
            "blockQuoteBackgroundColor",
            "thematicBreakColor",
            "strikethroughColor",
            "taskListUncheckedColor",
            "tableBorderColor",
            "tableHeaderBackgroundColor",
        ]

        #expect(
            styleFingerprint(source, excluding: paletteFields)
                == styleFingerprint(dark, excluding: paletteFields)
        )

        let darkFingerprint = styleFingerprint(dark)
        let expectedFingerprint = styleFingerprint(expectedPalette)
        for field in paletteFields {
            #expect(darkFingerprint[field] == expectedFingerprint[field])
        }
    }

    @Test("Compact mode scales only documented spatial metrics")
    func compactScalesOnlySpatialMetrics() {
        let source = distinctiveStyle()
        let compact = source.compact()
        let scaledFields: Set<String> = [
            "documentSpacing",
            "paragraphSpacing",
            "lineBreakSpacing",
            "blockQuoteSpacing",
            "blockQuoteContentSpacing",
            "blockQuotePadding",
            "blockQuoteVerticalPadding",
            "thematicBreakSpacing",
            "listItemSpacing",
            "listItemContentSpacing",
            "listMarkerSpacing",
            "listIndentation",
            "codeSpanPadding",
            "codeBlockPadding",
            "taskListSpacing",
            "taskListContentSpacing",
            "tableCellPadding",
        ]
        let spatialMetrics: [KeyPath<SwiftUIStyleConfiguration, CGFloat>] = [
            \.documentSpacing,
            \.paragraphSpacing,
            \.lineBreakSpacing,
            \.blockQuoteSpacing,
            \.blockQuoteContentSpacing,
            \.blockQuotePadding,
            \.blockQuoteVerticalPadding,
            \.thematicBreakSpacing,
            \.listItemSpacing,
            \.listItemContentSpacing,
            \.listMarkerSpacing,
            \.listIndentation,
            \.codeSpanPadding,
            \.codeBlockPadding,
            \.taskListSpacing,
            \.taskListContentSpacing,
            \.tableCellPadding,
        ]

        #expect(
            styleFingerprint(source, excluding: scaledFields)
                == styleFingerprint(compact, excluding: scaledFields)
        )
        for keyPath in spatialMetrics {
            #expect(compact[keyPath: keyPath] == source[keyPath: keyPath] * 0.75)
        }
    }

    @Test("Native presentation style normalizes metrics without mutating host input")
    func nativePresentationStyleNormalizesMetrics() {
        let source = SwiftUIStyleConfiguration(
            documentSpacing: -1,
            paragraphSpacing: -.infinity,
            lineBreakSpacing: .nan,
            blockQuoteSpacing: .infinity,
            blockQuoteContentSpacing: -2,
            blockQuotePadding: -3,
            blockQuoteVerticalPadding: -4,
            thematicBreakSpacing: -5,
            listItemSpacing: -6,
            listItemContentSpacing: -7,
            listMarkerSpacing: -8,
            listIndentation: -9,
            listMarkerWidth: -10,
            codeSpanPadding: -11,
            codeBlockPadding: -12,
            taskListSpacing: -13,
            taskListContentSpacing: -14,
            tableCellPadding: -15,
            blockQuoteBorderWidth: -16,
            blockQuoteCornerRadius: -17,
            codeCornerRadius: -18,
            imageMaxWidth: .nan,
            imageCornerRadius: -19,
            imagePlaceholderHeight: -20,
            tableBorderWidth: -21,
            tableCornerRadius: -22
        )
        let style = NativePresentationStyle(source)
        let normalizedMetrics = [
            style.document.spacing,
            style.paragraph.bottomSpacing,
            style.inline.lineSpacing,
            style.quote.spacing,
            style.quote.contentSpacing,
            style.quote.horizontalPadding,
            style.quote.verticalPadding,
            style.quote.borderWidth,
            style.quote.cornerRadius,
            style.list.itemSpacing,
            style.list.contentSpacing,
            style.list.indentation,
            style.list.markerWidth,
            style.task.contentSpacing,
            style.task.backgroundCornerRadius,
            style.table.rowSpacing,
            style.table.cellPadding,
            style.table.borderWidth,
            style.table.cornerRadius,
            style.codeBlock.blockPadding,
            style.codeBlock.spanPadding,
            style.codeBlock.cornerRadius,
            style.image.cornerRadius,
            style.image.placeholderHeight,
            style.thematicBreak.verticalSpacing,
        ]

        #expect(normalizedMetrics.allSatisfy { $0 == 0 })
        #expect(style.image.maximumWidth == .infinity)
        #expect(source.documentSpacing == -1)
        #expect(source.paragraphSpacing == -.infinity)
        #expect(source.lineBreakSpacing.isNaN)
        #expect(NativePresentationStyle(
            SwiftUIStyleConfiguration(imageMaxWidth: -1)
        ).image.maximumWidth == 0)
        #expect(NativePresentationStyle(
            SwiftUIStyleConfiguration(imageMaxWidth: .infinity)
        ).image.maximumWidth == .infinity)
        #expect(style.heading(level: 0).bottomSpacing == 12)
        #expect(style.heading(level: 1).bottomSpacing == 24)
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

    @Test("Materializes standard, compact, and dark presentation styles")
    func materializesPresentationStyleVariants() async throws {
        let document = try SwiftMarkdownParser().parse("""
        # Presentation

        > A quote with enough content to expose spacing and palette changes.

        - [x] Native style

        ```swift
        let answer = 42
        ```
        """)
        let standardContent = try await SwiftUIRenderer().render(document)
        let compactContent = try await SwiftUIRenderer(options: .init(
            styleConfiguration: SwiftUIStyleConfiguration().compact()
        )).render(document)
        let darkContent = try await SwiftUIRenderer(options: .init(
            styleConfiguration: SwiftUIStyleConfiguration().darkMode()
        )).render(document)

        let standard = try #require(ImageRenderer(content:
            standardContent
                .frame(width: 360, alignment: .leading)
                .padding(12)
                .background(.white)
        ).cgImage)
        let compact = try #require(ImageRenderer(content:
            compactContent
                .frame(width: 360, alignment: .leading)
                .padding(12)
                .background(.white)
        ).cgImage)
        let dark = try #require(ImageRenderer(content:
            darkContent
                .frame(width: 360, alignment: .leading)
                .padding(12)
                .background(.white)
        ).cgImage)
        let standardData = try #require(NSBitmapImageRep(cgImage: standard).representation(
            using: .png,
            properties: [:]
        ))
        let darkData = try #require(NSBitmapImageRep(cgImage: dark).representation(
            using: .png,
            properties: [:]
        ))

        #expect(compact.height < standard.height)
        #expect(dark.width == standard.width)
        #expect(dark.height == standard.height)
        #expect(darkData != standardData)
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

    private func distinctiveStyle() -> SwiftUIStyleConfiguration {
        SwiftUIStyleConfiguration(
            bodyFont: .custom("NativeBody", size: 11),
            codeFont: .custom("NativeCode", size: 12),
            headingFonts: [1: .custom("NativeHeading", size: 21)],
            tableHeaderFont: .custom("NativeTableHeader", size: 13),
            tableBodyFont: .custom("NativeTableBody", size: 14),
            taskListCheckboxFont: .custom("NativeTask", size: 15),
            textColor: Color(red: 0.01, green: 0.02, blue: 0.03),
            headingColor: Color(red: 0.04, green: 0.05, blue: 0.06),
            linkColor: Color(red: 0.07, green: 0.08, blue: 0.09),
            codeTextColor: Color(red: 0.10, green: 0.11, blue: 0.12),
            codeBackgroundColor: Color(red: 0.13, green: 0.14, blue: 0.15),
            blockQuoteBorderColor: Color(red: 0.16, green: 0.17, blue: 0.18),
            blockQuoteBackgroundColor: Color(red: 0.19, green: 0.20, blue: 0.21),
            thematicBreakColor: Color(red: 0.22, green: 0.23, blue: 0.24),
            listMarkerColor: Color(red: 0.25, green: 0.26, blue: 0.27),
            strikethroughColor: Color(red: 0.28, green: 0.29, blue: 0.30),
            taskListCheckedColor: Color(red: 0.31, green: 0.32, blue: 0.33),
            taskListUncheckedColor: Color(red: 0.34, green: 0.35, blue: 0.36),
            tableBorderColor: Color(red: 0.37, green: 0.38, blue: 0.39),
            tableBackgroundColor: Color(red: 0.40, green: 0.41, blue: 0.42),
            tableHeaderBackgroundColor: Color(red: 0.43, green: 0.44, blue: 0.45),
            tableCellBackgroundColor: Color(red: 0.46, green: 0.47, blue: 0.48),
            tableHeaderTextColor: Color(red: 0.49, green: 0.50, blue: 0.51),
            tableBodyTextColor: Color(red: 0.52, green: 0.53, blue: 0.54),
            documentSpacing: 1,
            paragraphSpacing: 2,
            lineBreakSpacing: 3,
            blockQuoteSpacing: 4,
            blockQuoteContentSpacing: 5,
            blockQuotePadding: 6,
            blockQuoteVerticalPadding: 7,
            thematicBreakSpacing: 8,
            listItemSpacing: 9,
            listItemContentSpacing: 10,
            listMarkerSpacing: 11,
            listIndentation: 12,
            listMarkerWidth: 13,
            codeSpanPadding: 14,
            codeBlockPadding: 15,
            taskListSpacing: 16,
            taskListContentSpacing: 17,
            tableCellPadding: 18,
            blockQuoteBorderWidth: 19,
            blockQuoteCornerRadius: 20,
            codeCornerRadius: 21,
            imageMaxWidth: 22,
            imageCornerRadius: 23,
            imagePlaceholderHeight: 24,
            tableBorderWidth: 25,
            tableCornerRadius: 26
        )
    }

    private func styleFingerprint(
        _ style: SwiftUIStyleConfiguration,
        excluding excludedFields: Set<String> = []
    ) -> [String: String] {
        Dictionary(uniqueKeysWithValues: Mirror(reflecting: style).children.compactMap { child in
            guard let label = child.label, !excludedFields.contains(label) else { return nil }
            return (label, String(reflecting: child.value))
        })
    }

    private func projectedTable(
        _ table: AST.GFMTableNode
    ) throws -> NativeDocumentProjection.Table {
        let plan = try NativeDocumentProjection(options: .init()).project(
            AST.DocumentNode(children: [table])
        )
        guard let first = plan.blocks.first,
              case let .table(projected) = first else {
            throw ProjectionTestError.missingTable
        }
        return projected
    }

    private func projectedLinks(
        _ inlines: [any ASTNode],
        baseURL: URL? = nil
    ) throws -> [(text: String, link: URL?)] {
        let plan = try NativeDocumentProjection(options: .init(baseURL: baseURL)).project(
            AST.DocumentNode(children: [AST.ParagraphNode(children: inlines)])
        )
        guard let first = plan.blocks.first,
              case let .paragraph(paragraph) = first else {
            throw ProjectionTestError.missingParagraph
        }
        return paragraph.fragments.compactMap { fragment in
            guard case let .text(text, _, link) = fragment else { return nil }
            return (text, link)
        }
    }
}

private enum ProjectionTestError: Error {
    case missingTable
    case missingParagraph
}
