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

    private let syntaxHighlighter: SyntaxHighlighter
    private let nativeInlineProjection: NativeInlineProjection
    private let nativeAdaptivePresentation: NativeAdaptivePresentation

    /// Initialize with rendering options
    public init(options: SwiftUIRenderOptions = .init()) {
        self.options = options
        self.syntaxHighlighter = SyntaxHighlighter()
        self.nativeInlineProjection = NativeInlineProjection(options: options)
        self.nativeAdaptivePresentation = NativeAdaptivePresentation(options: options)
    }

    /// Render a complete document AST to SwiftUI view
    public func render(_ document: AST.DocumentNode) async throws -> AnyView {
        let views = try await document.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            nativeAdaptivePresentation.present(.document(views))
            .modifier(SwiftUILinkActionModifier(handler: options.linkHandler))
        )
    }

    /// Render any AST node to SwiftUI view
    private func render(node: any ASTNode) async throws -> AnyView {
        switch node {
        case is AST.TextNode,
             is AST.EmphasisNode,
             is AST.StrongEmphasisNode,
             is AST.LinkNode,
             is AST.ImageNode,
             is AST.CodeSpanNode,
             is AST.LineBreakNode,
             is AST.SoftBreakNode,
             is AST.AutolinkNode,
             is AST.HTMLInlineNode,
             is AST.StrikethroughNode,
             is AST.FootnoteReferenceNode,
             is AST.InlineMathNode:
            return AnyView(
                try nativeInlineProjection.project([node])
                    .font(options.styleConfiguration.bodyFont)
                    .foregroundStyle(options.styleConfiguration.textColor)
            )

        case let paragraphNode as AST.ParagraphNode:
            return try await renderParagraph(paragraphNode)

        case let headingNode as AST.HeadingNode:
            return try await renderHeading(headingNode)

        case let codeBlockNode as AST.CodeBlockNode:
            return await renderCodeBlock(codeBlockNode)

        case let listNode as AST.ListNode:
            return try await renderList(listNode)

        case let listItemNode as AST.ListItemNode:
            return try await renderListItem(listItemNode)

        case let blockQuoteNode as AST.BlockQuoteNode:
            return try await renderBlockQuote(blockQuoteNode)

        case let thematicBreakNode as AST.ThematicBreakNode:
            return renderThematicBreak(thematicBreakNode)

        case let htmlBlockNode as AST.HTMLBlockNode:
            return renderHTMLBlock(htmlBlockNode)

        // GFM Extensions
        case let taskListItemNode as AST.GFMTaskListItemNode:
            return try await renderTaskListItem(taskListItemNode)

        case let tableNode as AST.GFMTableNode:
            return try await renderTable(tableNode)

        // Footnote Support
        case let footnoteDefinitionNode as AST.FootnoteDefinitionNode:
            return try await renderFootnoteDefinition(footnoteDefinitionNode)

        // Mermaid Support
        case let mermaidNode as AST.MermaidDiagramNode:
            return renderMermaidDiagram(mermaidNode)

        // Math Support
        case let mathBlockNode as AST.MathBlockNode:
            return renderMathBlock(mathBlockNode)

        default:
            throw SwiftUIRenderingError.unsupportedNodeType(node.nodeType)
        }
    }
}

// MARK: - Block Element Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render paragraph node
    private func renderParagraph(_ node: AST.ParagraphNode) async throws -> AnyView {
        let content = try nativeInlineProjection.project(node.children)
        return AnyView(
            content
                .font(options.styleConfiguration.bodyFont)
                .foregroundStyle(options.styleConfiguration.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, options.styleConfiguration.paragraphSpacing)
                .accessibilityElement(children: .combine)
        )
    }

    /// Render heading node
    private func renderHeading(_ node: AST.HeadingNode) async throws -> AnyView {
        let content = try nativeInlineProjection.project(node.children)

        let font = options.styleConfiguration.headingFont(for: node.level)
        let spacing = options.styleConfiguration.headingSpacing(for: node.level)

        return AnyView(
            content
                .font(font)
                .fontWeight(.bold)
                .foregroundStyle(options.styleConfiguration.headingColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, spacing)
                .accessibilityAddTraits(.isHeader)
                .accessibilityElement(children: .combine)
        )
    }

    /// Render block quote node
    private func renderBlockQuote(_ node: AST.BlockQuoteNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return nativeAdaptivePresentation.present(.blockQuote(childViews))
    }

    /// Render thematic break (horizontal rule)
    private func renderThematicBreak(_ node: AST.ThematicBreakNode) -> AnyView {
        return AnyView(
            Divider()
                .background(options.styleConfiguration.thematicBreakColor)
                .padding(.vertical, options.styleConfiguration.thematicBreakSpacing)
                .accessibilityLabel("Section divider")
                .accessibilityAddTraits(.isStaticText)
        )
    }
}

// MARK: - Code Block Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render code block node
    private func renderCodeBlock(_ node: AST.CodeBlockNode) async -> AnyView {
        let highlighted = await highlightedCode(for: node)

        return AnyView(
            ScrollView(.horizontal, showsIndicators: true) {
                highlighted.text
                    .font(options.styleConfiguration.codeFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(options.styleConfiguration.codeBlockPadding)
            }
            .background(highlighted.backgroundColor)
            .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
            .accessibilityLabel("Code block" + (node.language.map { " in \($0)" } ?? ""))
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
    }

    private func highlightedCode(for node: AST.CodeBlockNode) async -> (text: Text, backgroundColor: Color) {
        guard let theme = options.syntaxHighlightingTheme,
              let language = node.language,
              let tokens = await syntaxHighlighter.highlight(node.content, language: language) else {
            return (
                Text(node.content).foregroundStyle(options.styleConfiguration.codeTextColor),
                options.styleConfiguration.codeBackgroundColor
            )
        }

        let runs = SwiftUIRenderSemantics.codeRuns(source: node.content, tokens: tokens)
        var text = Text("")
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

    /// Render list node
    private func renderList(_ node: AST.ListNode) async throws -> AnyView {
        let itemViews = try await node.items.asyncMap { item in
            try await render(node: item)
        }
        let items = zip(node.items.indices, itemViews).map { index, view in
            let marker: NativeAdaptivePresentation.ListItem.Marker?
            if node.items[index] is AST.GFMTaskListItemNode {
                marker = nil
            } else if node.isOrdered {
                marker = .ordered(SwiftUIRenderSemantics.orderedListMarker(
                    startNumber: node.startNumber,
                    index: index
                ))
            } else {
                marker = .bullet
            }
            return NativeAdaptivePresentation.ListItem(marker: marker, content: view)
        }

        return nativeAdaptivePresentation.present(.list(items))
    }

    /// Render list item node
    private func renderListItem(_ node: AST.ListItemNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return nativeAdaptivePresentation.present(.content(childViews))
    }
}

// MARK: - GFM Extension Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render a footnote definition and preserve its complete block content.
    private func renderFootnoteDefinition(_ node: AST.FootnoteDefinitionNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return nativeAdaptivePresentation.present(.footnote(
            identifier: node.identifier,
            children: childViews
        ))
    }

    /// Render task list item node
    private func renderTaskListItem(_ node: AST.GFMTaskListItemNode) async throws -> AnyView {
        let content = try nativeInlineProjection.project(node.children)

        return nativeAdaptivePresentation.present(.task(
            isChecked: node.isChecked,
            content: content
        ))
    }

    /// Render table node
    private func renderTable(_ node: AST.GFMTableNode) async throws -> AnyView {
        let rows = try node.rows.map { row in
            let cells = try row.cells.enumerated().map { index, cell in
                let nodes: [any ASTNode] = cell.children.isEmpty
                    ? [AST.TextNode(content: cell.content)]
                    : cell.children
                return NativeAdaptivePresentation.Table.Cell(
                    content: try nativeInlineProjection.project(nodes),
                    alignment: index < node.alignments.count ? node.alignments[index] : .none,
                    columnIndex: index
                )
            }
            return NativeAdaptivePresentation.Table.Row(isHeader: row.isHeader, cells: cells)
        }

        return nativeAdaptivePresentation.present(.table(.init(rows: rows)))
    }
}

// MARK: - HTML Rendering (Fallback)

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render HTML block node (fallback to plain text)
    private func renderHTMLBlock(_ node: AST.HTMLBlockNode) -> AnyView {
        if let handler = options.richContentHandlers.htmlBlock {
            return handler(node)
        }

        return AnyView(
            Text(node.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)
                .padding(options.styleConfiguration.codeBlockPadding)
                .background(options.styleConfiguration.codeBackgroundColor)
                .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
                .accessibilityLabel("HTML content")
                .accessibilityValue(node.content)
                .accessibilityAddTraits(.isStaticText)
        )
    }
}

// MARK: - Math Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render math block node (display math)
    private func renderMathBlock(_ node: AST.MathBlockNode) -> AnyView {
        if let handler = options.richContentHandlers.mathBlock {
            return handler(node)
        }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: true) {
                Text(node.content)
                    .font(options.styleConfiguration.codeFont)
                    .foregroundStyle(options.styleConfiguration.codeTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(options.styleConfiguration.codeBlockPadding)
            }
            .background(options.styleConfiguration.codeBackgroundColor)
            .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
            .accessibilityLabel("Math expression")
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
    }
}

// MARK: - Mermaid Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render Mermaid diagram node
    private func renderMermaidDiagram(_ node: AST.MermaidDiagramNode) -> AnyView {
        if let handler = options.richContentHandlers.mermaid {
            return handler(node, options.mermaidConfiguration)
        }

        return renderMermaidFallback(node)
    }

    /// Fallback rendering for Mermaid when WebView is not available
    private func renderMermaidFallback(_ node: AST.MermaidDiagramNode) -> AnyView {
        nativeAdaptivePresentation.present(.mermaidFallback(
            diagramType: node.diagramType,
            source: node.content
        ))
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

// MARK: - Async Array Extension

extension Array {
    /// Async map function for rendering child nodes
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
