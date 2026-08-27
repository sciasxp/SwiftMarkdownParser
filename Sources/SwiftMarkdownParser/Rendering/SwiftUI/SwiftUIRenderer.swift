/// Native SwiftUI output rendering for Markdown documents.
///
/// This renderer provides a native SwiftUI implementation for displaying markdown content
/// with proper styling, accessibility support, and performance optimizations.

public import SwiftUI

// MARK: - SwiftUIRenderer

/// SwiftUI renderer that converts markdown AST nodes to SwiftUI views
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct SwiftUIRenderer {
    /// Rendering options for configuration and styling
    public let options: SwiftUIRenderOptions

    private let style: NativePresentationStyle
    private let syntaxHighlighter: SyntaxHighlighter
    private let nativeDocumentProjection: NativeDocumentProjection
    private let nativeInlineProjection: NativeInlineProjection
    private let nativeAdaptivePresentation: NativeAdaptivePresentation
    private let nativeRichContentProjection: NativeRichContentProjection
    private let nativeSemantics: NativePresentationSemantics
    private let nativeMaterializer: NativeViewMaterializer

    /// Initialize with rendering options
    public init(options: SwiftUIRenderOptions = .init()) {
        let style = NativePresentationStyle(options.styleConfiguration)
        let semantics = NativePresentationSemantics()
        let materializer = NativeViewMaterializer()
        let adaptivePresentation = NativeAdaptivePresentation(
            style: style,
            semantics: semantics,
            materializer: materializer
        )
        let richContentProjection = NativeRichContentProjection(
            options: options,
            style: style,
            adaptivePresentation: adaptivePresentation,
            semantics: semantics,
            materializer: materializer
        )

        self.options = options
        self.style = style
        self.syntaxHighlighter = SyntaxHighlighter()
        self.nativeDocumentProjection = NativeDocumentProjection(options: options)
        self.nativeInlineProjection = NativeInlineProjection(
            style: style.inline,
            richContentProjection: richContentProjection,
            materializer: materializer
        )
        self.nativeAdaptivePresentation = adaptivePresentation
        self.nativeRichContentProjection = richContentProjection
        self.nativeSemantics = semantics
        self.nativeMaterializer = materializer
    }

    /// Render a complete document AST to SwiftUI view
    public func render(_ document: AST.DocumentNode) async throws -> AnyView {
        let plan = try nativeDocumentProjection.project(document)
        let views = await materialize(plan.blocks)

        let documentView = nativeAdaptivePresentation.present(.document(views))
        return AnyView(documentView.modifier(SwiftUILinkActionModifier(handler: options.linkHandler)))
    }

    private func materialize(
        _ blocks: [NativeDocumentProjection.Block]
    ) async -> [NativeMaterializedView] {
        var views: [NativeMaterializedView] = []
        views.reserveCapacity(blocks.count)
        for block in blocks {
            views.append(await materialize(block))
        }
        return views
    }

    /// Materializes one block from a complete, already-validated document plan.
    private func materialize(
        _ block: NativeDocumentProjection.Block
    ) async -> NativeMaterializedView {
        switch block {
        case let .inline(plan):
            return nativeMaterializer.materialize(
                nativeInlineProjection.materialize(plan)
                    .font(style.document.font)
                    .foregroundStyle(style.document.textColor)
            )
        case let .paragraph(content):
            return renderParagraph(content)
        case let .heading(level, content):
            return renderHeading(level: level, content: content)
        case let .codeBlock(node):
            return await renderCodeBlock(node)
        case let .list(list):
            return await renderList(list)
        case let .content(children):
            return await renderContent(children)
        case let .blockQuote(children):
            return await renderBlockQuote(children)
        case .thematicBreak:
            return renderThematicBreak()
        case let .rich(request):
            return nativeRichContentProjection.project(request)
        case let .task(isChecked, content):
            return renderTaskListItem(isChecked: isChecked, content: content)
        case let .table(table):
            return renderTable(table)
        case let .footnote(identifier, children):
            return await renderFootnoteDefinition(identifier: identifier, children: children)
        }
    }
}

// MARK: - Block Element Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    private func renderParagraph(_ plan: NativeInlinePlan) -> NativeMaterializedView {
        let content = nativeInlineProjection.materialize(plan)
        return nativeMaterializer.materialize(
            content
                .font(style.paragraph.font)
                .foregroundStyle(style.paragraph.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, style.paragraph.bottomSpacing)
                .accessibilityElement(children: .combine)
        )
    }

    private func renderHeading(
        level: Int,
        content plan: NativeInlinePlan
    ) -> NativeMaterializedView {
        let content = nativeInlineProjection.materialize(plan)
        let heading = style.heading(level: level)

        return nativeMaterializer.materialize(
            content
                .font(heading.font)
                .fontWeight(.bold)
                .foregroundStyle(heading.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, heading.bottomSpacing)
                .accessibilityAddTraits(.isHeader)
                .accessibilityElement(children: .combine)
        )
    }

    private func renderBlockQuote(
        _ children: [NativeDocumentProjection.Block]
    ) async -> NativeMaterializedView {
        let childViews = await materialize(children)
        return nativeAdaptivePresentation.present(.blockQuote(childViews))
    }

    private func renderThematicBreak() -> NativeMaterializedView {
        return nativeMaterializer.materialize(
            Divider()
                .background(style.thematicBreak.color)
                .padding(.vertical, style.thematicBreak.verticalSpacing)
                .accessibilityLabel(Text(nativeSemantics.localized(.sectionDivider)))
                .accessibilityAddTraits(.isStaticText)
        )
    }
}

// MARK: - Code Block Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render code block node
    private func renderCodeBlock(_ node: AST.CodeBlockNode) async -> NativeMaterializedView {
        let highlighted = await highlightedCode(for: node)

        return nativeMaterializer.materialize(
            ScrollView(.horizontal, showsIndicators: true) {
                highlighted.text
                    .font(style.codeBlock.font)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(style.codeBlock.blockPadding)
            }
            .background(highlighted.backgroundColor)
            .clipShape(.rect(cornerRadius: style.codeBlock.cornerRadius))
            .accessibilityLabel(Text(nativeSemantics.localized(.codeBlock(language: node.language))))
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
    }

    private func highlightedCode(for node: AST.CodeBlockNode) async -> (text: Text, backgroundColor: Color) {
        guard let theme = options.syntaxHighlightingTheme,
              let language = node.language,
              let tokens = await syntaxHighlighter.highlight(node.content, language: language) else {
            return (
                Text(node.content).foregroundStyle(style.codeBlock.textColor),
                style.codeBlock.backgroundColor
            )
        }

        let runs = nativeSemantics.codeRuns(source: node.content, tokens: tokens)
        var text = Text(verbatim: "")
        for run in runs {
            let color = run.tokenType.flatMap { theme.tokenColors[$0] } ?? theme.textColor
            text = text + Text(run.text).foregroundStyle(color)
        }
        return (text, theme.backgroundColor)
    }
}

// MARK: - List Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    private func renderList(
        _ list: NativeDocumentProjection.List
    ) async -> NativeMaterializedView {
        var items: [NativeAdaptivePresentation.ListItem] = []
        items.reserveCapacity(list.items.count)

        for (index, item) in list.items.enumerated() {
            let view = await materialize(item.content)
            let marker: NativeAdaptivePresentation.ListItem.Marker?
            if item.isTask {
                marker = nil
            } else if list.isOrdered {
                marker = .ordered(nativeSemantics.orderedListMarker(
                    startNumber: list.startNumber,
                    index: index
                ))
            } else {
                marker = .bullet
            }
            items.append(NativeAdaptivePresentation.ListItem(marker: marker, content: view))
        }

        return nativeAdaptivePresentation.present(.list(items))
    }

    private func renderContent(
        _ children: [NativeDocumentProjection.Block]
    ) async -> NativeMaterializedView {
        let childViews = await materialize(children)
        return nativeAdaptivePresentation.present(.content(childViews))
    }
}

// MARK: - GFM Extension Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    private func renderFootnoteDefinition(
        identifier: String,
        children: [NativeDocumentProjection.Block]
    ) async -> NativeMaterializedView {
        let childViews = await materialize(children)

        return nativeAdaptivePresentation.present(.footnote(
            identifier: identifier,
            children: childViews
        ))
    }

    private func renderTaskListItem(
        isChecked: Bool,
        content plan: NativeInlinePlan
    ) -> NativeMaterializedView {
        let content = nativeInlineProjection.materialize(plan)

        return nativeAdaptivePresentation.present(.task(
            isChecked: isChecked,
            content: content
        ))
    }

    private func renderTable(
        _ table: NativeDocumentProjection.Table
    ) -> NativeMaterializedView {
        let columns = table.columns.map { column in
            NativeAdaptivePresentation.Table.Column(
                id: nativeMaterializer.identity(),
                alignment: column.alignment,
                header: column.header.map(nativeInlineProjection.materialize)
            )
        }
        let rows = table.rows.map { row in
            let cells = row.cells.map { cell in
                return NativeAdaptivePresentation.Table.Cell(
                    content: nativeInlineProjection.materialize(cell.content),
                    columnIndex: cell.columnIndex
                )
            }
            return NativeAdaptivePresentation.Table.Row(
                id: nativeMaterializer.identity(),
                cells: cells
            )
        }

        return nativeAdaptivePresentation.present(.table(.init(columns: columns, rows: rows)))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SwiftUILinkActionModifier: ViewModifier {
    let handler: (@Sendable (URL) -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let handler {
            content.environment(\.openURL, OpenURLAction { url in
                handler(url)
                return .handled
            })
        } else {
            content
        }
    }
}
