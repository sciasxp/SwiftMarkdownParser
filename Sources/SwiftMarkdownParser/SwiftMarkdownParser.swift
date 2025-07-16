// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A Swift package for parsing Markdown text into AST (Abstract Syntax Tree).
/// 
/// This package provides a lightweight, Swift-native solution for parsing
/// Markdown documents into a structured AST that can be rendered to various
/// output formats including HTML, SwiftUI, and more.
import Foundation

// MARK: - Error Types

/// Errors that can occur during markdown parsing
public enum MarkdownParsingError: Error, Sendable {
    case invalidTableStructure(String)
    case invalidInput(String)
    case tokenizationFailed(String)
    case parsingFailed(String)
    case invalidASTConstruction(String)
}

/// The main entry point for the Swift Markdown Parser.
/// 
/// This class provides methods to parse Markdown text into an AST that can
/// be consumed by various renderers for different output formats.
public final class SwiftMarkdownParser: Sendable {
    
    /// Configuration options for the parser
    public struct Configuration: Sendable {
        /// Enable GitHub Flavored Markdown extensions
        public let enableGFMExtensions: Bool
        
        /// Enable strict CommonMark compliance mode
        public let strictMode: Bool
        
        /// Maximum nesting depth for recursive elements
        public let maxNestingDepth: Int
        
        /// Enable source location tracking for debugging
        public let trackSourceLocations: Bool
        
        /// Maximum parsing time in seconds (0 = no limit)
        public let maxParsingTime: TimeInterval
        
        public init(
            enableGFMExtensions: Bool = true,
            strictMode: Bool = false,
            maxNestingDepth: Int = 100,
            trackSourceLocations: Bool = false,
            maxParsingTime: TimeInterval = 30.0
        ) {
            self.enableGFMExtensions = enableGFMExtensions
            self.strictMode = strictMode
            self.maxNestingDepth = maxNestingDepth
            self.trackSourceLocations = trackSourceLocations
            self.maxParsingTime = maxParsingTime
        }
        
        public static let `default` = Configuration()
    }
    
    private let configuration: Configuration
    
    /// Creates a new instance of the markdown parser.
    /// - Parameter configuration: Parser configuration options
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Parses the given Markdown text and returns an AST representation.
    /// 
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: A `DocumentNode` containing the parsed AST structure
    /// - Throws: `MarkdownParserError` if parsing fails
    public func parseToAST(_ markdown: String) async throws -> AST.DocumentNode {
        let tokenizer = MarkdownTokenizer(markdown)
        let tokenStream = TokenStream(tokenizer.tokenize())
        
        let blockParser = BlockParser(tokenStream: tokenStream, configuration: configuration)
        let document = try blockParser.parseDocument()
        
        let inlineParser = InlineParser(tokenStream: tokenStream, configuration: configuration)
        
        // Post-process AST to resolve inline content
        let processedDocument = try await processNodeForInlineContent(document, using: inlineParser)
        
        guard let finalDocument = processedDocument as? AST.DocumentNode else {
            throw MarkdownParsingError.invalidASTConstruction("Root node must be a DocumentNode")
        }
        
        return finalDocument
    }
    
    /// Process AST nodes to parse inline content and GFM extensions
    private func processNodesForInlineContent(_ nodes: [ASTNode], using inlineParser: InlineParser) async throws -> [ASTNode] {
        var processedNodes: [ASTNode] = []
        
        for node in nodes {
            let processedNode = try await processNodeForInlineContent(node, using: inlineParser)
            processedNodes.append(processedNode)
        }
        
        return processedNodes
    }
    
    /// Process a single AST node for inline content and GFM extensions
    private func processNodeForInlineContent(_ node: ASTNode, using inlineParser: InlineParser) async throws -> ASTNode {
        
        if let fragment = node as? AST.FragmentNode {
            let processedChildren = try await processNodesForInlineContent(fragment.children, using: inlineParser)
            return AST.FragmentNode(children: processedChildren, sourceLocation: fragment.sourceLocation)
        }
        
        // Handle GFM table nodes - process their cells for inline content
        if let tableNode = node as? AST.GFMTableNode {
            let processedRows = try await processNodesForInlineContent(tableNode.rows, using: inlineParser)
            return AST.GFMTableNode(
                rows: processedRows.compactMap { $0 as? AST.GFMTableRowNode },
                alignments: tableNode.alignments,
                sourceLocation: tableNode.sourceLocation
            )
        }
        
        if let tableRowNode = node as? AST.GFMTableRowNode {
            let processedCells = try await processNodesForInlineContent(tableRowNode.cells, using: inlineParser)
            return AST.GFMTableRowNode(
                cells: processedCells.compactMap { $0 as? AST.GFMTableCellNode },
                isHeader: tableRowNode.isHeader,
                sourceLocation: tableRowNode.sourceLocation
            )
        }
        
        if let tableCellNode = node as? AST.GFMTableCellNode {
            // Parse table cell content as inline markdown
            if !tableCellNode.content.isEmpty {
                let inlineNodes = try inlineParser.parseInlineContent(tableCellNode.content)
                let enhancedNodes = try await parseInlineContentWithGFM(inlineNodes, using: inlineParser)
                return AST.GFMTableCellNode(
                    children: enhancedNodes,
                    isHeader: tableCellNode.isHeader,
                    alignment: tableCellNode.alignment,
                    sourceLocation: tableCellNode.sourceLocation
                )
            }
            return tableCellNode
        }
        
        switch node.nodeType {
        case .paragraph:
            if let paragraphNode = node as? AST.ParagraphNode {
                return try await processParagraphForInlineContent(paragraphNode, using: inlineParser)
            }
            
        case .heading:
            if let headingNode = node as? AST.HeadingNode {
                return try await processHeadingForInlineContent(headingNode, using: inlineParser)
            }
            
        case .blockQuote:
            if let blockQuoteNode = node as? AST.BlockQuoteNode {
                let processedChildren = try await processNodesForInlineContent(blockQuoteNode.children, using: inlineParser)
                return AST.BlockQuoteNode(
                    children: processedChildren,
                    sourceLocation: blockQuoteNode.sourceLocation
                )
            }
            
        case .list:
            if let listNode = node as? AST.ListNode {
                return try await processListForInlineContent(listNode, using: inlineParser)
            }
            
        case .listItem:
            if let listItemNode = node as? AST.ListItemNode {
                return try await processListItemForInlineContent(listItemNode, using: inlineParser)
            }
            
        case .taskListItem:
            if let taskListItemNode = node as? AST.GFMTaskListItemNode {
                return try await processTaskListItemForInlineContent(taskListItemNode, using: inlineParser)
            }
            
        default:
            // For other node types, process children if they exist
            if !node.children.isEmpty {
                let processedChildren = try await processNodesForInlineContent(node.children, using: inlineParser)
                return createNodeWithProcessedChildren(node, children: processedChildren)
            }
        }
        
        return node
    }
    
    
    /// Process paragraph for inline content and GFM extensions
    private func processParagraphForInlineContent(_ paragraph: AST.ParagraphNode, using inlineParser: InlineParser) async throws -> ASTNode {
        // Parse inline content with GFM extensions
        let inlineNodes = try await parseInlineContentWithGFM(paragraph.children, using: inlineParser)
        
        return AST.ParagraphNode(
            children: inlineNodes,
            sourceLocation: paragraph.sourceLocation
        )
    }
    
    /// Process heading for inline content
    private func processHeadingForInlineContent(_ heading: AST.HeadingNode, using inlineParser: InlineParser) async throws -> ASTNode {
        let inlineNodes = try await parseInlineContentWithGFM(heading.children, using: inlineParser)
        
        return AST.HeadingNode(
            level: heading.level,
            children: inlineNodes,
            sourceLocation: heading.sourceLocation
        )
    }
    
    /// Process list for GFM task lists and inline content
    private func processListForInlineContent(_ list: AST.ListNode, using inlineParser: InlineParser) async throws -> ASTNode {
        var processedItems: [ASTNode] = []
        
        for item in list.items {
            // Check if this is a task list item
            if let listItemNode = item as? AST.ListItemNode,
               let paragraphNode = listItemNode.children.first as? AST.ParagraphNode {
                
                // Reconstruct the text content from the paragraph's nodes (including inline formatting)
                let fullText = AST.GFMTableCellNode.extractPlainText(from: paragraphNode.children)
                
                // Check if this looks like a task list item
                if GFMUtils.isTaskListItem("- " + fullText) { // Add dummy marker since isTaskListItem expects it
                    // Parse the task list item (add dummy marker for parsing)
                    if let taskInfo = GFMUtils.parseTaskListItem("- " + fullText) {
                        // Extract the task content nodes directly from the paragraph, preserving inline formatting
                        let taskContentNodes = extractTaskContentFromParagraph(paragraphNode)
                        let taskListItem = AST.GFMTaskListItemNode(
                            isChecked: taskInfo.isChecked,
                            children: taskContentNodes,
                            sourceLocation: listItemNode.sourceLocation
                        )
                        processedItems.append(taskListItem)
                    } else {
                        // Fall back to regular list item
                        let processedItem = try await processListItemForInlineContent(listItemNode, using: inlineParser)
                        processedItems.append(processedItem)
                    }
                } else {
                    // Regular list item - process normally
                    let processedItem = try await processListItemForInlineContent(listItemNode, using: inlineParser)
                    processedItems.append(processedItem)
                }
            } else {
                // Regular list item (not containing a paragraph or different structure)
                let processedItem = try await processNodeForInlineContent(item, using: inlineParser)
                processedItems.append(processedItem)
            }
        }
        
        return AST.ListNode(
            isOrdered: list.isOrdered,
            startNumber: list.startNumber,
            items: processedItems,
            sourceLocation: list.sourceLocation
        )
    }
    
    /// Process list item for inline content
    private func processListItemForInlineContent(_ listItem: AST.ListItemNode, using inlineParser: InlineParser) async throws -> ASTNode {
        let processedChildren = try await processNodesForInlineContent(listItem.children, using: inlineParser)
        
        return AST.ListItemNode(
            children: processedChildren,
            sourceLocation: listItem.sourceLocation
        )
    }
    
    /// Process task list item for inline content
    private func processTaskListItemForInlineContent(_ taskListItem: AST.GFMTaskListItemNode, using inlineParser: InlineParser) async throws -> ASTNode {
        let processedChildren = try await parseInlineContentWithGFM(taskListItem.children, using: inlineParser)
        
        return AST.GFMTaskListItemNode(
            isChecked: taskListItem.isChecked,
            children: processedChildren,
            sourceLocation: taskListItem.sourceLocation
        )
    }
    
    /// Extract task content from paragraph, preserving inline formatting but removing task list marker
    private func extractTaskContentFromParagraph(_ paragraph: AST.ParagraphNode) -> [ASTNode] {
        var result: [ASTNode] = []
        var foundTaskMarker = false
        
        for node in paragraph.children {
            if !foundTaskMarker {
                // Look for the task marker pattern: [x], [ ], etc.
                if let textNode = node as? AST.TextNode {
                    let content = textNode.content
                    // Check if this text node contains a task marker
                    if content.contains("[") && (content.contains("]") || result.isEmpty) {
                        // This might be the start of a task marker
                        if content.hasPrefix("[") && content.count >= 3 && content.hasSuffix("]") {
                            // This is a complete task marker like "[x]"
                            foundTaskMarker = true
                            continue
                        } else if content == "[" {
                            // This might be the start of a split task marker
                            foundTaskMarker = true
                            continue
                        }
                    }
                    
                    // Skip the first whitespace after finding task marker
                    if foundTaskMarker && content.trimmingCharacters(in: .whitespaces).isEmpty && result.isEmpty {
                        continue
                    }
                }
                
                // If we haven't found the task marker yet, skip this node
                if !foundTaskMarker {
                    continue
                }
            }
            
            // Add all nodes after the task marker
            result.append(node)
        }
        
        return result
    }
    
    /// Parse inline content with GFM extensions (strikethrough, autolinks)
    private func parseInlineContentWithGFM(_ nodes: [ASTNode], using inlineParser: InlineParser) async throws -> [ASTNode] {
        var result: [ASTNode] = []
        
        for node in nodes {
            if let textNode = node as? AST.TextNode {
                let enhancedNodes = try await parseGFMInlineExtensions(textNode.content, using: inlineParser)
                result.append(contentsOf: enhancedNodes)
            } else {
                // Process children if they exist
                if !node.children.isEmpty {
                    let processedChildren = try await parseInlineContentWithGFM(node.children, using: inlineParser)
                    let newNode = createNodeWithProcessedChildren(node, children: processedChildren)
                    result.append(newNode)
                } else {
                    result.append(node)
                }
            }
        }
        
        return result
    }
    
    /// Parse GFM inline extensions (strikethrough, autolinks) in text
    private func parseGFMInlineExtensions(_ text: String, using inlineParser: InlineParser) async throws -> [ASTNode] {
        // First parse regular inline content
        var nodes = try inlineParser.parseInlineContent(text)
        
        // Then enhance with GFM extensions
        nodes = try await enhanceWithStrikethrough(nodes, using: inlineParser)
        nodes = try await enhanceWithAutolinks(nodes, using: inlineParser)
        
        return nodes
    }
    
    /// Enhance nodes with strikethrough parsing
    private func enhanceWithStrikethrough(_ nodes: [ASTNode], using inlineParser: InlineParser) async throws -> [ASTNode] {
        var result: [ASTNode] = []
        
        for node in nodes {
            if let textNode = node as? AST.TextNode,
                           GFMUtils.containsStrikethrough(textNode.content) {
            
            let strikethroughNodes = inlineParser.parseGFMStrikethrough(textNode.content)
                if !strikethroughNodes.isEmpty {
                    result.append(contentsOf: strikethroughNodes)
                } else {
                    result.append(node)
                }
            } else {
                result.append(node)
            }
        }
        
        return result
    }
    
    /// Enhance nodes with autolink parsing
    private func enhanceWithAutolinks(_ nodes: [ASTNode], using inlineParser: InlineParser) async throws -> [ASTNode] {
        var result: [ASTNode] = []
        
        for node in nodes {
            if let textNode = node as? AST.TextNode,
                           GFMUtils.containsAutolinks(textNode.content) {
            
            let autolinkNodes = inlineParser.parseGFMAutolinks(textNode.content)
                if !autolinkNodes.isEmpty {
                    result.append(contentsOf: autolinkNodes)
                } else {
                    result.append(node)
                }
            } else {
                result.append(node)
            }
        }
        
        return result
    }
    
    /// Create a new node with processed children
    private func createNodeWithProcessedChildren(_ originalNode: ASTNode, children: [ASTNode]) -> ASTNode {
        switch originalNode.nodeType {
        case .document:
            if let documentNode = originalNode as? AST.DocumentNode {
                return AST.DocumentNode(
                    children: children,
                    sourceLocation: documentNode.sourceLocation
                )
            }
            
        case .paragraph:
            if let paragraphNode = originalNode as? AST.ParagraphNode {
                return AST.ParagraphNode(
                    children: children,
                    sourceLocation: paragraphNode.sourceLocation
                )
            }
            
        case .heading:
            if let headingNode = originalNode as? AST.HeadingNode {
                return AST.HeadingNode(
                    level: headingNode.level,
                    children: children,
                    sourceLocation: headingNode.sourceLocation
                )
            }
            
        case .blockQuote:
            if let blockQuoteNode = originalNode as? AST.BlockQuoteNode {
                return AST.BlockQuoteNode(
                    children: children,
                    sourceLocation: blockQuoteNode.sourceLocation
                )
            }
            
        case .listItem:
            if let listItemNode = originalNode as? AST.ListItemNode {
                return AST.ListItemNode(
                    children: children,
                    sourceLocation: listItemNode.sourceLocation
                )
            }
            
        case .emphasis:
            if let emphasisNode = originalNode as? AST.EmphasisNode {
                return AST.EmphasisNode(
                    children: children,
                    sourceLocation: emphasisNode.sourceLocation
                )
            }
            
        case .strongEmphasis:
            if let strongEmphasisNode = originalNode as? AST.StrongEmphasisNode {
                return AST.StrongEmphasisNode(
                    children: children,
                    sourceLocation: strongEmphasisNode.sourceLocation
                )
            }
            
        case .link:
            if let linkNode = originalNode as? AST.LinkNode {
                return AST.LinkNode(
                    url: linkNode.url,
                    title: linkNode.title,
                    children: children,
                    sourceLocation: linkNode.sourceLocation
                )
            }
            
        case .table:
            if let tableNode = originalNode as? AST.GFMTableNode {
                return AST.GFMTableNode(
                    rows: children.compactMap { $0 as? AST.GFMTableRowNode },
                    alignments: tableNode.alignments,
                    sourceLocation: tableNode.sourceLocation
                )
            }
            
        case .tableRow:
            if let rowNode = originalNode as? AST.GFMTableRowNode {
                return AST.GFMTableRowNode(
                    cells: children.compactMap { $0 as? AST.GFMTableCellNode },
                    isHeader: rowNode.isHeader,
                    sourceLocation: rowNode.sourceLocation
                )
            }
            
        case .tableCell:
            // Table cells typically don't have children that need processing
            // Return the original node unchanged
            return originalNode
            
        default:
            // For unknown node types, return original
            return originalNode
        }
        
        return originalNode
    }
    
    /// Convenience method to parse Markdown and render to HTML.
    /// 
    /// - Parameter markdown: The Markdown text to parse
    /// - Parameter context: Rendering context for HTML output
    /// - Returns: HTML string representation
    /// - Throws: `MarkdownParserError` or `RendererError` if parsing or rendering fails
    public func parseToHTML(_ markdown: String, context: RenderContext = RenderContext()) async throws -> String {
        let ast = try await parseToAST(markdown)
        let htmlRenderer = HTMLRenderer(context: context)
        return try await htmlRenderer.render(document: ast)
    }
}

// MARK: - Parser Errors

/// Errors that can occur during markdown parsing
public enum MarkdownParserError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case nestingTooDeep(Int)
    case malformedMarkdown(String, SourceLocation?)
    case unsupportedFeature(String)
    case internalError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .nestingTooDeep(let depth):
            return "Nesting too deep: \(depth) levels"
        case .malformedMarkdown(let message, let location):
            if let location = location {
                return "Malformed markdown at line \(location.line), column \(location.column): \(message)"
            } else {
                return "Malformed markdown: \(message)"
            }
        case .unsupportedFeature(let feature):
            return "Unsupported feature: \(feature)"
        case .internalError(let message):
            return "Internal parser error: \(message)"
        }
    }
}

// MARK: - Enhanced HTML Renderer Implementation

/// Enhanced HTML renderer implementation with full feature support
public struct HTMLRenderer: MarkdownRenderer {
    public typealias Output = String
    
    internal let context: RenderContext
    internal let configuration: SwiftMarkdownParser.Configuration
    
    public init(context: RenderContext = RenderContext(), configuration: SwiftMarkdownParser.Configuration = SwiftMarkdownParser.Configuration()) {
        self.context = context
        self.configuration = configuration
    }
    
    public func render(document: AST.DocumentNode) async throws -> String {
        var html = ""
        
        for child in document.children {
            html += try await render(node: child)
        }
        
        return html
    }
    
    public func render(node: ASTNode) async throws -> String {
        switch node {
        case let textNode as AST.TextNode:
            return RendererUtils.escapeHTML(textNode.content)
            
        case let paragraphNode as AST.ParagraphNode:
            var content = ""
            for child in paragraphNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .paragraph,
                sourceLocation: paragraphNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<p\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</p>\n"
            
        case let headingNode as AST.HeadingNode:
            var content = ""
            for child in headingNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .heading,
                sourceLocation: headingNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<h\(headingNode.level)\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</h\(headingNode.level)>\n"
            
        case let blockQuoteNode as AST.BlockQuoteNode:
            var content = ""
            for child in blockQuoteNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .blockQuote,
                sourceLocation: blockQuoteNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<blockquote\(RendererUtils.formatHTMLAttributes(attributes))>\n\(content)</blockquote>\n"
            
        case let listNode as AST.ListNode:
            var content = ""
            for child in listNode.children {
                content += try await render(node: child)
            }
            
            let tagName = listNode.isOrdered ? "ol" : "ul"
            var attributes = RendererUtils.htmlAttributes(
                for: .list,
                sourceLocation: listNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            
            // Add start number attribute for ordered lists when necessary
            if listNode.isOrdered, let startNumber = listNode.startNumber, startNumber != 1 {
                attributes["start"] = String(startNumber)
            }
            
            // If this list contains at least one task-list item, add a
            // class and styling so consumers (and GitHub-style CSS) can target it.
            if listNode.items.contains(where: { $0 is AST.GFMTaskListItemNode }) {
                let existingClass = attributes["class"] ?? ""
                let taskListClass = "task-list"
                attributes["class"] = existingClass.isEmpty ? taskListClass : existingClass + " " + taskListClass
                
                // Add inline styling for task list container
                var taskListStyles: [String] = []
                taskListStyles.append("list-style: none")
                taskListStyles.append("padding-left: 0")
                taskListStyles.append("margin: 16px 0")
                
                let existingStyle = attributes["style"] ?? ""
                attributes["style"] = existingStyle.isEmpty ? taskListStyles.joined(separator: "; ") : existingStyle + "; " + taskListStyles.joined(separator: "; ")
            }
            
            return "<\(tagName)\(RendererUtils.formatHTMLAttributes(attributes))>\n\(content)</\(tagName)>\n"
            
        case let listItemNode as AST.ListItemNode:
            var html = "<li>"
            
            // Render content
            for child in listItemNode.children {
                html += try await render(node: child)
            }
            
            html += "</li>\n"
            return html
            
        case let codeBlockNode as AST.CodeBlockNode:
            return try await renderCodeBlock(codeBlockNode)
            
        case let thematicBreakNode as AST.ThematicBreakNode:
            let attributes = RendererUtils.htmlAttributes(
                for: .thematicBreak,
                sourceLocation: thematicBreakNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<hr\(RendererUtils.formatHTMLAttributes(attributes)) />\n"
            
        case let emphasisNode as AST.EmphasisNode:
            var content = ""
            for child in emphasisNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .emphasis,
                sourceLocation: emphasisNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<em\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</em>"
            
        case let strongNode as AST.StrongEmphasisNode:
            var content = ""
            for child in strongNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .strongEmphasis,
                sourceLocation: strongNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<strong\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</strong>"
            
        case let strikethroughNode as AST.StrikethroughNode:
            var content = ""
            for child in strikethroughNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .strikethrough,
                sourceLocation: strikethroughNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<del\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</del>"
            
        case let linkNode as AST.LinkNode:
            var content = ""
            for child in linkNode.children {
                content += try await render(node: child)
            }
            
            guard let normalizedURL = RendererUtils.normalizeURL(linkNode.url, baseURL: context.baseURL) else {
                // If URL is invalid/unsafe, render as plain text
                return content
            }
            
            var attributes = RendererUtils.htmlAttributes(
                for: .link,
                sourceLocation: linkNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            attributes["href"] = normalizedURL
            
            if let title = linkNode.title {
                attributes["title"] = title
            }
            
            return "<a\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</a>"
            
        case let imageNode as AST.ImageNode:
            let altText = imageNode.altText
            
            guard let normalizedURL = RendererUtils.normalizeURL(imageNode.url, baseURL: context.baseURL) else {
                // If URL is invalid/unsafe, render alt text
                return RendererUtils.escapeHTML(altText)
            }
            
            var attributes = RendererUtils.htmlAttributes(
                for: .image,
                sourceLocation: imageNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            attributes["src"] = normalizedURL
            attributes["alt"] = altText
            
            if let title = imageNode.title {
                attributes["title"] = title
            }
            
            return "<img\(RendererUtils.formatHTMLAttributes(attributes)) />"
            
        case let codeSpanNode as AST.CodeSpanNode:
            let attributes = RendererUtils.htmlAttributes(
                for: .codeSpan,
                sourceLocation: codeSpanNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<code\(RendererUtils.formatHTMLAttributes(attributes))>\(RendererUtils.escapeHTML(codeSpanNode.content))</code>"
            
        case let lineBreakNode as AST.LineBreakNode:
            return lineBreakNode.isHard ? "<br />\n" : "\n"
            
        case _ as AST.SoftBreakNode:
            return " "
            
        case let autolinkNode as AST.AutolinkNode:
            let url = autolinkNode.url
            let text = autolinkNode.text
            guard let normalizedURL = RendererUtils.normalizeURL(url, baseURL: context.baseURL) else {
                return RendererUtils.escapeHTML(text)
            }
            var attributes = RendererUtils.htmlAttributes(
                for: .autolink,
                sourceLocation: autolinkNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            attributes["href"] = normalizedURL
            return "<a\(RendererUtils.formatHTMLAttributes(attributes))>\(RendererUtils.escapeHTML(text))</a>"
            
        case let htmlBlockNode as AST.HTMLBlockNode:
            if context.sanitizeHTML {
                return RendererUtils.escapeHTML(htmlBlockNode.content)
            }
            return htmlBlockNode.content
            
        case let htmlInlineNode as AST.HTMLInlineNode:
            if context.sanitizeHTML {
                return RendererUtils.escapeHTML(htmlInlineNode.content)
            }
            return htmlInlineNode.content
            
        // GFM Extensions
        case let tableNode as AST.GFMTableNode:
            let renderer = HTMLRenderer(context: context, configuration: configuration)
            return try await renderer.renderGFMTable(tableNode)
            
        case let taskListItemNode as AST.GFMTaskListItemNode:
            return try await renderGFMTaskListItem(taskListItemNode)
            
        default:
            throw RendererError.unsupportedNodeType(node.nodeType)
        }
    }
    
    private func renderCodeBlock(_ codeBlockNode: AST.CodeBlockNode) async throws -> String {
        let language = codeBlockNode.language
        let content = codeBlockNode.content
        
        // Check if syntax highlighting is enabled and we have a language
        if let language = language,
           context.styleConfiguration.syntaxHighlighting.enabled,
           context.styleConfiguration.syntaxHighlighting.supportedLanguages.contains(language.lowercased()) {
            
            // Use syntax highlighting engine
            let registry = SyntaxHighlightingRegistry()
            if let engine = await registry.engine(for: language) {
                do {
                    let tokens = try await engine.highlight(content, language: language)
                    let highlightedHTML = renderSyntaxTokensToHTML(tokens, originalCode: content, cssPrefix: context.styleConfiguration.syntaxHighlighting.cssPrefix)
                    
                    var codeAttributes: [String: String] = [:]
                    codeAttributes["class"] = "language-" + language
                    
                    let preAttributes = RendererUtils.htmlAttributes(
                        for: .codeBlock,
                        sourceLocation: codeBlockNode.sourceLocation,
                        styleConfig: context.styleConfiguration
                    )
                    
                    return "<pre\(RendererUtils.formatHTMLAttributes(preAttributes))><code\(RendererUtils.formatHTMLAttributes(codeAttributes))>\(highlightedHTML)</code></pre>\n"
                } catch {
                    // Fall back to plain rendering if highlighting fails
                }
            }
        }
        
        // Fall back to plain code block rendering
        let escapedContent = RendererUtils.escapeHTML(content)
        var codeAttributes: [String: String] = [:]
        
        if let language = language {
            codeAttributes["class"] = "language-" + language
        }
        
        let preAttributes = RendererUtils.htmlAttributes(
            for: .codeBlock,
            sourceLocation: codeBlockNode.sourceLocation,
            styleConfig: context.styleConfiguration
        )
        
        return "<pre\(RendererUtils.formatHTMLAttributes(preAttributes))><code\(RendererUtils.formatHTMLAttributes(codeAttributes))>\(escapedContent)</code></pre>\n"
    }
    
    private func renderSyntaxTokensToHTML(_ tokens: [SyntaxToken], originalCode: String, cssPrefix: String) -> String {
        var html = ""
        var lastEndIndex: String.Index?
        
        for token in tokens {
            let escapedContent = RendererUtils.escapeHTML(token.content)
            
            // Add any whitespace that was skipped between tokens
            if let lastEnd = lastEndIndex, lastEnd < token.range.lowerBound {
                // Extract the whitespace between tokens from the original code
                let whitespace = String(originalCode[lastEnd..<token.range.lowerBound])
                html += RendererUtils.escapeHTML(whitespace)
            }
            
            let cssClass = cssPrefix + token.tokenType.rawValue
            html += "<span class=\"\(cssClass)\">\(escapedContent)</span>"
            lastEndIndex = token.range.upperBound
        }
        
        // Add any remaining content after the last token
        if let lastEnd = lastEndIndex, lastEnd < originalCode.endIndex {
            let remaining = String(originalCode[lastEnd..<originalCode.endIndex])
            html += RendererUtils.escapeHTML(remaining)
        }
        
        return html
    }
}
