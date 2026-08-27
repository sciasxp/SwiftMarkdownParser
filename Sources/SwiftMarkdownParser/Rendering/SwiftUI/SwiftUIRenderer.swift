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

    /// Initialize with rendering options
    public init(options: SwiftUIRenderOptions = .init()) {
        self.options = options
        self.syntaxHighlighter = SyntaxHighlighter()
        self.nativeInlineProjection = NativeInlineProjection(options: options)
    }

    /// Render a complete document AST to SwiftUI view
    public func render(_ document: AST.DocumentNode) async throws -> AnyView {
        let views = try await document.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            VStack(alignment: .leading, spacing: options.styleConfiguration.documentSpacing) {
                ForEach(IdentifiedValue.wrap(views)) { item in
                    item.value
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

        return AnyView(
            HStack(alignment: .top, spacing: options.styleConfiguration.blockQuoteSpacing) {
                Rectangle()
                    .fill(options.styleConfiguration.blockQuoteBorderColor)
                    .frame(width: options.styleConfiguration.blockQuoteBorderWidth)

                VStack(alignment: .leading, spacing: options.styleConfiguration.blockQuoteContentSpacing) {
                    ForEach(IdentifiedValue.wrap(childViews)) { item in
                        item.value
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, options.styleConfiguration.blockQuotePadding)
            .padding(.vertical, options.styleConfiguration.blockQuoteVerticalPadding)
            .background(options.styleConfiguration.blockQuoteBackgroundColor)
            .clipShape(.rect(cornerRadius: options.styleConfiguration.blockQuoteCornerRadius))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
        )
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
        // Determine if each item is a task-list item so we can suppress the normal list marker.
        let isTaskListFlags: [Bool] = node.items.map { $0 is AST.GFMTaskListItemNode }

        return AnyView(
            VStack(alignment: .leading, spacing: options.styleConfiguration.listItemSpacing) {
                ForEach(IdentifiedValue.wrap(itemViews)) { item in
                    HStack(alignment: .top, spacing: options.styleConfiguration.listMarkerSpacing) {
                        // Only show the default list marker when this item is NOT a GFM task-list item.
                        if !isTaskListFlags[item.index] {
                            if node.isOrdered {
                                Text(SwiftUIRenderSemantics.orderedListMarker(
                                    startNumber: node.startNumber,
                                    index: item.index
                                ))
                                    .font(options.styleConfiguration.bodyFont)
                                    .foregroundStyle(options.styleConfiguration.listMarkerColor)
                                    .frame(minWidth: options.styleConfiguration.listMarkerWidth, alignment: .trailing)
                            } else {
                                Text("•")
                                    .font(options.styleConfiguration.bodyFont)
                                    .foregroundStyle(options.styleConfiguration.listMarkerColor)
                                    .frame(width: options.styleConfiguration.listMarkerWidth, alignment: .center)
                            }
                        }
                        item.value
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, options.styleConfiguration.listIndentation)
            .accessibilityElement(children: .contain)
        )
    }

    /// Render list item node
    private func renderListItem(_ node: AST.ListItemNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            VStack(alignment: .leading, spacing: options.styleConfiguration.listItemContentSpacing) {
                ForEach(IdentifiedValue.wrap(childViews)) { item in
                    item.value
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        )
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

        return AnyView(
            HStack(alignment: .top, spacing: options.styleConfiguration.listMarkerSpacing) {
                Text("[\(node.identifier)]")
                    .font(options.styleConfiguration.bodyFont)
                    .foregroundStyle(options.styleConfiguration.textColor.opacity(0.65))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: options.styleConfiguration.listItemContentSpacing) {
                    ForEach(IdentifiedValue.wrap(childViews)) { item in
                        item.value
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Footnote \(node.identifier)")
        )
    }

    /// Render task list item node
    private func renderTaskListItem(_ node: AST.GFMTaskListItemNode) async throws -> AnyView {
        let content = try nativeInlineProjection.project(node.children)

        return AnyView(
            HStack(alignment: .top, spacing: options.styleConfiguration.taskListSpacing) {
                Image(systemName: node.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isChecked ? options.styleConfiguration.taskListCheckedColor : options.styleConfiguration.taskListUncheckedColor)
                    .font(.system(size: 18, weight: node.isChecked ? .bold : .regular))
                    .accessibilityHidden(true)

                content
                    .font(options.styleConfiguration.bodyFont)
                    .foregroundStyle(options.styleConfiguration.textColor)
                    .opacity(node.isChecked ? 0.7 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
            .background(
                node.isChecked ?
                RoundedRectangle(cornerRadius: 6)
                    .fill(options.styleConfiguration.taskListCheckedColor.opacity(0.08))
                : nil
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(node.isChecked ? "Completed task" : "Incomplete task"): \(content.accessibilityText)"
            )
        )
    }

    /// Render table node
    private func renderTable(_ node: AST.GFMTableNode) async throws -> AnyView {
        let headerRows = node.rows.filter { $0.isHeader }
        let bodyRows = node.rows.filter { !$0.isHeader }

        let headerViews = try await headerRows.asyncMap { row in
            try await renderTableRow(row, alignments: node.alignments, isHeader: true)
        }

        let bodyViews = try await bodyRows.asyncMap { row in
            try await renderTableRow(row, alignments: node.alignments, isHeader: false)
        }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    // Header
                    if !headerViews.isEmpty {
                        ForEach(IdentifiedValue.wrap(headerViews)) { item in
                            item.value
                        }

                        Divider()
                            .background(options.styleConfiguration.tableBorderColor)
                            .gridCellUnsizedAxes(.horizontal)
                    }

                    // Body
                    ForEach(IdentifiedValue.wrap(bodyViews)) { item in
                        item.value

                        if item.index < bodyViews.count - 1 {
                            Divider()
                                .background(options.styleConfiguration.tableBorderColor)
                                .gridCellUnsizedAxes(.horizontal)
                        }
                    }
                }
                .background(options.styleConfiguration.tableBackgroundColor)
                .clipShape(.rect(cornerRadius: options.styleConfiguration.tableCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: options.styleConfiguration.tableCornerRadius)
                        .stroke(options.styleConfiguration.tableBorderColor, lineWidth: options.styleConfiguration.tableBorderWidth)
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Table")
        )
    }

    /// Render table row
    private func renderTableRow(_ row: AST.GFMTableRowNode, alignments: [GFMTableAlignment], isHeader: Bool) async throws -> AnyView {
        let cellContents = try row.cells.map { cell in
            let nodes: [any ASTNode] = cell.children.isEmpty
                ? [AST.TextNode(content: cell.content)]
                : cell.children
            return try nativeInlineProjection.project(nodes)
        }

        return AnyView(
            GridRow(alignment: .top) {
                ForEach(IdentifiedValue.wrap(cellContents)) { item in
                    let alignment = item.index < alignments.count ? alignments[item.index] : .none

                    item.value
                        .font(isHeader ? options.styleConfiguration.tableHeaderFont : options.styleConfiguration.tableBodyFont)
                        .foregroundStyle(isHeader ? options.styleConfiguration.tableHeaderTextColor : options.styleConfiguration.tableBodyTextColor)
                        .fontWeight(isHeader ? .bold : .regular)
                        .frame(maxWidth: .infinity, alignment: swiftUIAlignment(from: alignment))
                        .padding(options.styleConfiguration.tableCellPadding)
                        .background(isHeader ? options.styleConfiguration.tableHeaderBackgroundColor : options.styleConfiguration.tableCellBackgroundColor)
                        .overlay(
                            Rectangle()
                                .stroke(options.styleConfiguration.tableBorderColor, lineWidth: options.styleConfiguration.tableBorderWidth)
                        )
                        .accessibilityLabel(isHeader ? "Header: \(item.value.accessibilityText)" : item.value.accessibilityText)
                        .accessibilityAddTraits(isHeader ? .isHeader : .isStaticText)
                }
            }
        )
    }

    /// Convert GFM table alignment to SwiftUI alignment
    private func swiftUIAlignment(from alignment: GFMTableAlignment) -> Alignment {
        switch alignment {
        case .left, .none:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
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
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                // Header with diagram type
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                    Text("Mermaid Diagram")
                        .font(options.styleConfiguration.codeFont.bold())
                        .foregroundStyle(options.styleConfiguration.textColor)

                    if let diagramType = node.diagramType {
                        Text("(\(diagramType))")
                            .font(options.styleConfiguration.codeFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, options.styleConfiguration.codeBlockPadding)
                .padding(.top, options.styleConfiguration.codeBlockPadding)

                // Code content
                ScrollView(.horizontal) {
                    Text(node.content)
                        .font(options.styleConfiguration.codeFont)
                        .foregroundStyle(options.styleConfiguration.codeTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, options.styleConfiguration.codeBlockPadding)
                        .padding(.bottom, options.styleConfiguration.codeBlockPadding)
                }
            }
            .background(options.styleConfiguration.codeBackgroundColor)
            .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: options.styleConfiguration.codeCornerRadius)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
            .accessibilityLabel("Mermaid diagram: \(node.diagramType ?? "unknown type")")
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
    }
}

private struct IdentifiedValue<Value>: Identifiable {
    let id: Int
    let index: Int
    let value: Value

    static func wrap(_ values: [Value]) -> [Self] {
        values.enumerated().map { index, value in
            Self(id: index, index: index, value: value)
        }
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
