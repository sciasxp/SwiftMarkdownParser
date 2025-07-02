// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A Swift package for parsing Markdown text into AST (Abstract Syntax Tree).
/// 
/// This package provides a lightweight, Swift-native solution for parsing
/// Markdown documents into a structured AST that can be rendered to various
/// output formats including HTML, SwiftUI, and more.
import Foundation

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
        
        public init(
            enableGFMExtensions: Bool = true,
            strictMode: Bool = false,
            maxNestingDepth: Int = 100,
            trackSourceLocations: Bool = false
        ) {
            self.enableGFMExtensions = enableGFMExtensions
            self.strictMode = strictMode
            self.maxNestingDepth = maxNestingDepth
            self.trackSourceLocations = trackSourceLocations
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
    public func parseToAST(_ markdown: String) async throws -> DocumentNode {
        // Step 1: Tokenize the input
        let tokenizer = MarkdownTokenizer(markdown)
        let tokens = tokenizer.tokenize()
        let tokenStream = TokenStream(tokens)
        
        // Step 2: Parse blocks
        let blockParser = BlockParser(tokenStream: tokenStream, configuration: configuration)
        var document = try blockParser.parseDocument()
        
        // Step 3: Parse inlines within blocks
        document = try await parseInlinesInDocument(document)
        
        return document
    }
    
    /// Recursively parse inline elements within block elements
    private func parseInlinesInDocument(_ document: DocumentNode) async throws -> DocumentNode {
        let processedChildren = try await processChildrenForInlines(document.children)
        return DocumentNode(children: processedChildren, sourceLocation: document.sourceLocation)
    }
    
    /// Process children nodes to parse inline elements
    private func processChildrenForInlines(_ children: [ASTNode]) async throws -> [ASTNode] {
        var processedChildren: [ASTNode] = []
        
        for child in children {
            let processedChild = try await processNodeForInlines(child)
            processedChildren.append(processedChild)
        }
        
        return processedChildren
    }
    
    /// Process a single node to parse inline elements
    private func processNodeForInlines(_ node: ASTNode) async throws -> ASTNode {
        switch node {
        case let paragraph as ParagraphNode:
            return try await processParagraphInlines(paragraph)
            
        case let heading as HeadingNode:
            return try await processHeadingInlines(heading)
            
        case let blockQuote as BlockQuoteNode:
            let processedChildren = try await processChildrenForInlines(blockQuote.children)
            return BlockQuoteNode(children: processedChildren, sourceLocation: blockQuote.sourceLocation)
            
        case let list as ListNode:
            let processedChildren = try await processChildrenForInlines(list.children)
            return ListNode(
                isOrdered: list.isOrdered,
                startNumber: list.startNumber,
                delimiter: list.delimiter,
                bulletChar: list.bulletChar,
                isTight: list.isTight,
                children: processedChildren,
                sourceLocation: list.sourceLocation
            )
            
        case let listItem as ListItemNode:
            let processedChildren = try await processChildrenForInlines(listItem.children)
            return ListItemNode(children: processedChildren, sourceLocation: listItem.sourceLocation)
            
        case let table as TableNode:
            let processedChildren = try await processChildrenForInlines(table.children)
            return TableNode(
                children: processedChildren,
                columnAlignments: table.columnAlignments,
                sourceLocation: table.sourceLocation
            )
            
        case let tableRow as TableRowNode:
            let processedChildren = try await processChildrenForInlines(tableRow.children)
            return TableRowNode(
                children: processedChildren,
                isHeader: tableRow.isHeader,
                sourceLocation: tableRow.sourceLocation
            )
            
        case let tableCell as TableCellNode:
            let processedChildren = try await processChildrenForInlines(tableCell.children)
            return TableCellNode(
                children: processedChildren,
                alignment: tableCell.alignment,
                sourceLocation: tableCell.sourceLocation
            )
            
        default:
            // For nodes that don't contain inline content, return as-is
            return node
        }
    }
    
    /// Process paragraph to parse inline elements
    private func processParagraphInlines(_ paragraph: ParagraphNode) async throws -> ParagraphNode {
        // Convert text content to tokens and parse inlines
        let textContent = extractTextContent(from: paragraph.children)
        let inlineNodes = try parseInlineContent(textContent)
        
        return ParagraphNode(children: inlineNodes, sourceLocation: paragraph.sourceLocation)
    }
    
    /// Process heading to parse inline elements
    private func processHeadingInlines(_ heading: HeadingNode) async throws -> HeadingNode {
        // Convert text content to tokens and parse inlines
        let textContent = extractTextContent(from: heading.children)
        let inlineNodes = try parseInlineContent(textContent)
        
        return HeadingNode(
            level: heading.level,
            isSetext: heading.isSetext,
            children: inlineNodes,
            sourceLocation: heading.sourceLocation
        )
    }
    
    /// Extract text content from nodes
    private func extractTextContent(from nodes: [ASTNode]) -> String {
        return nodes.compactMap { node in
            if let textNode = node as? TextNode {
                return textNode.content
            }
            return nil
        }.joined()
    }
    
    /// Parse inline content from text
    private func parseInlineContent(_ text: String) throws -> [ASTNode] {
        guard !text.isEmpty else { return [] }
        
        // Tokenize the text
        let tokenizer = MarkdownTokenizer(text)
        let tokens = tokenizer.tokenize()
        let tokenStream = TokenStream(tokens)
        
        // Parse inlines
        let inlineParser = InlineParser(tokenStream: tokenStream, configuration: configuration)
        return try inlineParser.parseInlines()
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
    
    private let context: RenderContext
    
    public init(context: RenderContext = RenderContext()) {
        self.context = context
    }
    
    public func render(document: DocumentNode) async throws -> String {
        var html = ""
        
        for child in document.children {
            html += try await render(node: child)
        }
        
        return html
    }
    
    public func render(node: ASTNode) async throws -> String {
        switch node {
        case let textNode as TextNode:
            return RendererUtils.escapeHTML(textNode.content)
            
        case let paragraphNode as ParagraphNode:
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
            
        case let headingNode as HeadingNode:
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
            
        case let blockQuoteNode as BlockQuoteNode:
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
            
        case let listNode as ListNode:
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
            
            if listNode.isOrdered, let startNumber = listNode.startNumber, startNumber != 1 {
                attributes["start"] = String(startNumber)
            }
            
            return "<\(tagName)\(RendererUtils.formatHTMLAttributes(attributes))>\n\(content)</\(tagName)>\n"
            
        case let listItemNode as ListItemNode:
            var content = ""
            for child in listItemNode.children {
                content += try await render(node: child)
            }
            let attributes = RendererUtils.htmlAttributes(
                for: .listItem,
                sourceLocation: listItemNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<li\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</li>\n"
            
        case let codeBlockNode as CodeBlockNode:
            let escapedContent = RendererUtils.escapeHTML(codeBlockNode.content)
            var codeAttributes: [String: String] = [:]
            
            if let language = codeBlockNode.language, context.styleConfiguration.syntaxHighlighting.enabled {
                codeAttributes["class"] = context.styleConfiguration.syntaxHighlighting.cssPrefix + language
            }
            
            let preAttributes = RendererUtils.htmlAttributes(
                for: .codeBlock,
                sourceLocation: codeBlockNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            
            return "<pre\(RendererUtils.formatHTMLAttributes(preAttributes))><code\(RendererUtils.formatHTMLAttributes(codeAttributes))>\(escapedContent)</code></pre>\n"
            
        case let thematicBreakNode as ThematicBreakNode:
            let attributes = RendererUtils.htmlAttributes(
                for: .thematicBreak,
                sourceLocation: thematicBreakNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<hr\(RendererUtils.formatHTMLAttributes(attributes)) />\n"
            
        case let emphasisNode as EmphasisNode:
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
            
        case let strongNode as StrongEmphasisNode:
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
            
        case let strikethroughNode as StrikethroughNode:
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
            
        case let linkNode as LinkNode:
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
            
        case let imageNode as ImageNode:
            var altText = ""
            for child in imageNode.children {
                // For alt text, we want plain text without HTML tags
                if let textNode = child as? TextNode {
                    altText += textNode.content
                }
            }
            
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
            
        case let codeSpanNode as CodeSpanNode:
            let escapedContent = RendererUtils.escapeHTML(codeSpanNode.content)
            let attributes = RendererUtils.htmlAttributes(
                for: .codeSpan,
                sourceLocation: codeSpanNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            return "<code\(RendererUtils.formatHTMLAttributes(attributes))>\(escapedContent)</code>"
            
        case let htmlInlineNode as HTMLInlineNode:
            if context.sanitizeHTML {
                return RendererUtils.escapeHTML(htmlInlineNode.content)
            } else {
                return htmlInlineNode.content
            }
            
        case let htmlBlockNode as HTMLBlockNode:
            if context.sanitizeHTML {
                return RendererUtils.escapeHTML(htmlBlockNode.content)
            } else {
                return htmlBlockNode.content + "\n"
            }
            
        case let lineBreakNode as LineBreakNode:
            if lineBreakNode.isHard {
                return "<br />\n"
            } else {
                return "\n"
            }
            
        case _ as SoftBreakNode:
            return " "
            
        case let autolinkNode as AutolinkNode:
            let url = autolinkNode.url
            guard let normalizedURL = RendererUtils.normalizeURL(url, baseURL: context.baseURL) else {
                return RendererUtils.escapeHTML(url)
            }
            
            let attributes = RendererUtils.htmlAttributes(
                for: .autolink,
                sourceLocation: autolinkNode.sourceLocation,
                styleConfig: context.styleConfiguration
            )
            
            let href = autolinkNode.linkType == .email ? "mailto:\(normalizedURL)" : normalizedURL
            
            return "<a href=\"\(RendererUtils.escapeHTMLAttribute(href))\"\(RendererUtils.formatHTMLAttributes(attributes))>\(RendererUtils.escapeHTML(url))</a>"
            
        default:
            throw RendererError.unsupportedNodeType(node.nodeType)
        }
    }
}
