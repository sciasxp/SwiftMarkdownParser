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

    /// Initialize with rendering options
    public init(options: SwiftUIRenderOptions = .init()) {
        self.options = options
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
        )
    }

    /// Render any AST node to SwiftUI view
    private func render(node: ASTNode) async throws -> AnyView {
        switch node {
        case let textNode as AST.TextNode:
            return renderText(textNode)

        case let paragraphNode as AST.ParagraphNode:
            return try await renderParagraph(paragraphNode)

        case let headingNode as AST.HeadingNode:
            return try await renderHeading(headingNode)

        case let emphasisNode as AST.EmphasisNode:
            return try await renderEmphasis(emphasisNode)

        case let strongNode as AST.StrongEmphasisNode:
            return try await renderStrongEmphasis(strongNode)

        case let linkNode as AST.LinkNode:
            return try await renderLink(linkNode)

        case let imageNode as AST.ImageNode:
            return renderImage(imageNode)

        case let codeSpanNode as AST.CodeSpanNode:
            return renderCodeSpan(codeSpanNode)

        case let codeBlockNode as AST.CodeBlockNode:
            return renderCodeBlock(codeBlockNode)

        case let listNode as AST.ListNode:
            return try await renderList(listNode)

        case let listItemNode as AST.ListItemNode:
            return try await renderListItem(listItemNode)

        case let blockQuoteNode as AST.BlockQuoteNode:
            return try await renderBlockQuote(blockQuoteNode)

        case let thematicBreakNode as AST.ThematicBreakNode:
            return renderThematicBreak(thematicBreakNode)

        case let lineBreakNode as AST.LineBreakNode:
            return renderLineBreak(lineBreakNode)

        case _ as AST.SoftBreakNode:
            return renderSoftBreak()

        case let autolinkNode as AST.AutolinkNode:
            return renderAutolink(autolinkNode)

        case let htmlBlockNode as AST.HTMLBlockNode:
            return renderHTMLBlock(htmlBlockNode)

        case let htmlInlineNode as AST.HTMLInlineNode:
            return renderHTMLInline(htmlInlineNode)

        // GFM Extensions
        case let taskListItemNode as AST.GFMTaskListItemNode:
            return try await renderTaskListItem(taskListItemNode)

        case let strikethroughNode as AST.StrikethroughNode:
            return try await renderStrikethrough(strikethroughNode)

        case let tableNode as AST.GFMTableNode:
            return try await renderTable(tableNode)

        // Mermaid Support
        case let mermaidNode as AST.MermaidDiagramNode:
            return renderMermaidDiagram(mermaidNode)

        // Math Support
        case let mathBlockNode as AST.MathBlockNode:
            return renderMathBlock(mathBlockNode)

        case let inlineMathNode as AST.InlineMathNode:
            return renderInlineMath(inlineMathNode)

        default:
            throw SwiftUIRenderingError.unsupportedNodeType(node.nodeType)
        }
    }
}

// MARK: - Text Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render text node
    private func renderText(_ node: AST.TextNode) -> AnyView {
        return AnyView(
            Text(node.content)
                .font(options.styleConfiguration.bodyFont)
                .foregroundStyle(options.styleConfiguration.textColor)
                .accessibilityLabel(node.content)
        )
    }

    /// Render soft break (space)
    private func renderSoftBreak() -> AnyView {
        return AnyView(
            Text(" ")
                .font(options.styleConfiguration.bodyFont)
        )
    }

    /// Render line break
    private func renderLineBreak(_ node: AST.LineBreakNode) -> AnyView {
        if node.isHard {
            return AnyView(
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: options.styleConfiguration.lineBreakSpacing)
            )
        } else {
            return AnyView(
                Text("\n")
                    .font(options.styleConfiguration.bodyFont)
            )
        }
    }
}

// MARK: - Block Element Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render paragraph node
    private func renderParagraph(_ node: AST.ParagraphNode) async throws -> AnyView {
        // Check if paragraph contains only text-compatible elements
        if canUseTextCombination(for: node.children) {
            // Use combined text approach for proper wrapping
            let combinedText = try await createCombinedText(from: node.children)

            return AnyView(
                combinedText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, options.styleConfiguration.paragraphSpacing)
                    .accessibilityElement(children: .combine)
            )
        } else {
            // Use separate views for mixed content with links and images
            let childViews = try await node.children.asyncMap { child in
                try await render(node: child)
            }

            return AnyView(
                // Use flexible layout that handles both inline and block elements
                HStack(spacing: 0) {
                    ForEach(IdentifiedValue.wrap(childViews)) { item in
                        item.value
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, options.styleConfiguration.paragraphSpacing)
                .accessibilityElement(children: .combine)
            )
        }
    }

    /// Check if nodes can be combined into a single Text view
    private func canUseTextCombination(for nodes: [ASTNode]) -> Bool {
        for node in nodes {
            if !isTextCompatible(node) {
                return false
            }
        }
        return true
    }

    /// Check if a node is compatible with Text combination
    private func isTextCompatible(_ node: ASTNode) -> Bool {
        switch node {
        case _ as AST.TextNode,
             _ as AST.CodeSpanNode,
             _ as AST.InlineMathNode,
             _ as AST.LineBreakNode,
             _ as AST.SoftBreakNode,
             _ as AST.HTMLInlineNode:
            return true
        case let emphasisNode as AST.EmphasisNode:
            for child in emphasisNode.children {
                if !isTextCompatible(child) {
                    return false
                }
            }
            return true
        case let strongNode as AST.StrongEmphasisNode:
            for child in strongNode.children {
                if !isTextCompatible(child) {
                    return false
                }
            }
            return true
        case let strikethroughNode as AST.StrikethroughNode:
            for child in strikethroughNode.children {
                if !isTextCompatible(child) {
                    return false
                }
            }
            return true
        case _ as AST.LinkNode,
             _ as AST.ImageNode,
             _ as AST.AutolinkNode:
            return false
        default:
            return false
        }
    }

    /// Create a combined Text view from child nodes that supports proper text wrapping
    private func createCombinedText(from nodes: [ASTNode]) async throws -> Text {
        var combinedText = Text("")

        for node in nodes {
            let textComponent = try await createTextComponent(from: node)
            combinedText = combinedText + textComponent
        }

        return combinedText
            .font(options.styleConfiguration.bodyFont)
            .foregroundStyle(options.styleConfiguration.textColor)
    }

    /// Create a Text component from an AST node
    private func createTextComponent(from node: ASTNode) async throws -> Text {
        switch node {
        case let textNode as AST.TextNode:
            return Text(textNode.content)

        case let emphasisNode as AST.EmphasisNode:
            let childText = try await createCombinedText(from: emphasisNode.children)
            return childText.italic()

        case let strongNode as AST.StrongEmphasisNode:
            let childText = try await createCombinedText(from: strongNode.children)
            return childText.fontWeight(.bold)

        case let codeSpanNode as AST.CodeSpanNode:
            return Text(codeSpanNode.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)

        case let inlineMathNode as AST.InlineMathNode:
            return Text(inlineMathNode.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)

        case let strikethroughNode as AST.StrikethroughNode:
            let childText = try await createCombinedText(from: strikethroughNode.children)
            return childText
                .strikethrough()
                .foregroundStyle(options.styleConfiguration.strikethroughColor)

        case _ as AST.LineBreakNode:
            return Text("\n")

        case _ as AST.SoftBreakNode:
            return Text(" ")

        case let htmlInlineNode as AST.HTMLInlineNode:
            // For HTML inline, just render as plain text
            return Text(htmlInlineNode.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)

        default:
            // For other node types, try to extract text content
            if !node.children.isEmpty {
                return try await createCombinedText(from: node.children)
            } else {
                return Text("")
            }
        }
    }

    /// Render heading node
    private func renderHeading(_ node: AST.HeadingNode) async throws -> AnyView {
        let combinedText = try await createCombinedText(from: node.children)

        let font = options.styleConfiguration.headingFont(for: node.level)
        let spacing = options.styleConfiguration.headingSpacing(for: node.level)

        return AnyView(
            combinedText
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

// MARK: - Inline Element Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render emphasis (italic) node
    private func renderEmphasis(_ node: AST.EmphasisNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            HStack(spacing: 0) {
                ForEach(IdentifiedValue.wrap(childViews)) { item in
                    item.value
                }
            }
            .italic()
            .accessibilityAddTraits(.isStaticText)
        )
    }

    /// Render strong emphasis (bold) node
    private func renderStrongEmphasis(_ node: AST.StrongEmphasisNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            HStack(spacing: 0) {
                ForEach(IdentifiedValue.wrap(childViews)) { item in
                    item.value
                }
            }
            .fontWeight(.bold)
            .accessibilityAddTraits(.isStaticText)
        )
    }

    /// Render link node
    private func renderLink(_ node: AST.LinkNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        guard let url = URL(string: node.url) else {
            // Invalid URL, render as plain text
            return AnyView(
                HStack(spacing: 0) {
                    ForEach(IdentifiedValue.wrap(childViews)) { item in
                        item.value
                    }
                }
            )
        }

        return AnyView(
            Button(action: {
                options.linkHandler?(url)
            }) {
                HStack(spacing: 0) {
                    ForEach(IdentifiedValue.wrap(childViews)) { item in
                        item.value
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundStyle(options.styleConfiguration.linkColor)
            .underline()
            .accessibilityLabel("Link: \(node.url)")
            .accessibilityAddTraits(.isLink)
            .accessibilityHint("Double tap to open link")
        )
    }

    /// Render image node
    private func renderImage(_ node: AST.ImageNode) -> AnyView {
        guard let url = URL(string: node.url) else {
            // Invalid URL, show alt text
            return AnyView(
                Text(node.altText)
                    .font(options.styleConfiguration.bodyFont)
                    .foregroundStyle(options.styleConfiguration.textColor)
                    .accessibilityLabel(node.altText)
            )
        }

        return AnyView(
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: options.styleConfiguration.imageMaxWidth)
                    .clipShape(.rect(cornerRadius: options.styleConfiguration.imageCornerRadius))
            } placeholder: {
                ProgressView()
                    .frame(height: options.styleConfiguration.imagePlaceholderHeight)
            }
            .accessibilityLabel(node.altText)
            .accessibilityAddTraits(.isImage)
        )
    }

    /// Render code span node
    private func renderCodeSpan(_ node: AST.CodeSpanNode) -> AnyView {
        return AnyView(
            Text(node.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)
                .padding(.horizontal, options.styleConfiguration.codeSpanPadding)
                .background(options.styleConfiguration.codeBackgroundColor)
                .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
                .accessibilityLabel("Code: \(node.content)")
                .accessibilityAddTraits(.isStaticText)
        )
    }

    /// Render autolink node
    private func renderAutolink(_ node: AST.AutolinkNode) -> AnyView {
        guard let url = URL(string: node.url) else {
            return AnyView(
                Text(node.text)
                    .font(options.styleConfiguration.bodyFont)
                    .foregroundStyle(options.styleConfiguration.textColor)
            )
        }

        return AnyView(
            Button(action: {
                options.linkHandler?(url)
            }) {
                Text(node.text)
                    .font(options.styleConfiguration.bodyFont)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundStyle(options.styleConfiguration.linkColor)
            .underline()
            .accessibilityLabel("Link: \(node.url)")
            .accessibilityAddTraits(.isLink)
            .accessibilityHint("Double tap to open link")
        )
    }
}

// MARK: - Code Block Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render code block node
    private func renderCodeBlock(_ node: AST.CodeBlockNode) -> AnyView {
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
            .accessibilityLabel("Code block" + (node.language.map { " in \($0)" } ?? ""))
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
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
                                Text("\(item.index + 1).")
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

    /// Render task list item node
    private func renderTaskListItem(_ node: AST.GFMTaskListItemNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            HStack(alignment: .top, spacing: options.styleConfiguration.taskListSpacing) {
                Button(action: {
                    // Task list items are typically read-only in rendered content
                    // But we could add a callback here for interactive task lists
                }) {
                    ZStack {
                        // Background circle for checked items to make them more prominent
                        if node.isChecked {
                            Circle()
                                .fill(options.styleConfiguration.taskListCheckedColor)
                                .frame(width: 20, height: 20)
                        }

                        // Checkbox icon
                        Image(systemName: node.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(node.isChecked ? .white : options.styleConfiguration.taskListUncheckedColor)
                            .font(.system(size: 18, weight: node.isChecked ? .bold : .regular))
                            .shadow(color: node.isChecked ? .black.opacity(0.1) : .clear, radius: 1, x: 0, y: 1)
                    }
                    .scaleEffect(node.isChecked ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: node.isChecked)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(true) // Read-only by default
                .accessibilityLabel(node.isChecked ? "Completed task" : "Incomplete task")
                .accessibilityAddTraits(.isButton)

                VStack(alignment: .leading, spacing: options.styleConfiguration.taskListContentSpacing) {
                    ForEach(IdentifiedValue.wrap(childViews)) { item in
                        item.value
                            .opacity(node.isChecked ? 0.7 : 1.0) // Dim completed tasks slightly
                            .overlay(
                                // Add subtle strikethrough effect for completed tasks
                                node.isChecked ?
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(options.styleConfiguration.taskListCheckedColor.opacity(0.6))
                                    .offset(y: 0)
                                : nil
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2) // Add slight vertical padding for better visual separation
            .background(
                // Subtle background highlight for checked items
                node.isChecked ?
                RoundedRectangle(cornerRadius: 6)
                    .fill(options.styleConfiguration.taskListCheckedColor.opacity(0.08))
                : nil
            )
            .accessibilityElement(children: .combine)
        )
    }

    /// Render strikethrough node
    private func renderStrikethrough(_ node: AST.StrikethroughNode) async throws -> AnyView {
        let childViews = try await node.children.asyncMap { child in
            try await render(node: child)
        }

        return AnyView(
            HStack(spacing: 0) {
                ForEach(IdentifiedValue.wrap(childViews)) { item in
                    item.value
                }
            }
            .strikethrough()
            .foregroundStyle(options.styleConfiguration.strikethroughColor)
            .accessibilityAddTraits(.isStaticText)
        )
    }

    /// Render table node
    private func renderTable(_ node: AST.GFMTableNode) async throws -> AnyView {
        let headerRows = node.rows.filter { $0.isHeader }
        let bodyRows = node.rows.filter { !$0.isHeader }

        let headerViews = headerRows.map { row in
            renderTableRow(row, alignments: node.alignments, isHeader: true)
        }

        let bodyViews = bodyRows.map { row in
            renderTableRow(row, alignments: node.alignments, isHeader: false)
        }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    if !headerViews.isEmpty {
                        ForEach(IdentifiedValue.wrap(headerViews)) { item in
                            item.value
                        }

                        Divider()
                            .background(options.styleConfiguration.tableBorderColor)
                    }

                    // Body
                    ForEach(IdentifiedValue.wrap(bodyViews)) { item in
                        item.value

                        if item.index < bodyViews.count - 1 {
                            Divider()
                                .background(options.styleConfiguration.tableBorderColor)
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
    private func renderTableRow(_ row: AST.GFMTableRowNode, alignments: [GFMTableAlignment], isHeader: Bool) -> AnyView {
        return AnyView(
            HStack(alignment: .top, spacing: 0) {
                ForEach(IdentifiedValue.wrap(row.cells)) { item in
                    let alignment = item.index < alignments.count ? alignments[item.index] : .none

                    Text(item.value.content)
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
                        .accessibilityLabel(isHeader ? "Header: \(item.value.content)" : item.value.content)
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

    /// Render HTML inline node (fallback to plain text)
    private func renderHTMLInline(_ node: AST.HTMLInlineNode) -> AnyView {
        return AnyView(
            Text(node.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)
                .padding(.horizontal, options.styleConfiguration.codeSpanPadding)
                .background(options.styleConfiguration.codeBackgroundColor)
                .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
                .accessibilityLabel("HTML: \(node.content)")
                .accessibilityAddTraits(.isStaticText)
        )
    }
}

// MARK: - Math Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render math block node (display math)
    private func renderMathBlock(_ node: AST.MathBlockNode) -> AnyView {
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

    /// Render inline math node
    private func renderInlineMath(_ node: AST.InlineMathNode) -> AnyView {
        return AnyView(
            Text(node.content)
                .font(options.styleConfiguration.codeFont)
                .foregroundStyle(options.styleConfiguration.codeTextColor)
                .padding(.horizontal, options.styleConfiguration.codeSpanPadding)
                .background(options.styleConfiguration.codeBackgroundColor)
                .clipShape(.rect(cornerRadius: options.styleConfiguration.codeCornerRadius))
                .accessibilityLabel("Math: \(node.content)")
                .accessibilityAddTraits(.isStaticText)
        )
    }
}

// MARK: - Mermaid Rendering

@available(iOS 17.0, macOS 14.0, *)
extension SwiftUIRenderer {

    /// Render Mermaid diagram node
    private func renderMermaidDiagram(_ node: AST.MermaidDiagramNode) -> AnyView {
        // For now, always use fallback rendering to avoid MainActor complexity
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
    let id: UUID
    let index: Int
    let value: Value

    static func wrap(_ values: [Value]) -> [Self] {
        values.enumerated().map { index, value in
            Self(id: UUID(), index: index, value: value)
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
