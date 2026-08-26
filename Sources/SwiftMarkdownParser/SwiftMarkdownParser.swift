// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A Swift package for parsing Markdown text into AST (Abstract Syntax Tree).
///
/// This package provides a lightweight, Swift-native solution for parsing
/// Markdown documents into a structured AST that can be rendered to various
/// output formats including HTML, SwiftUI, and more.
import Foundation

// MARK: - Error Types

/// The single error family produced while constructing a Markdown Document.
public enum MarkdownParsingError: Error, LocalizedError, Sendable, Equatable {
    public enum Resource: String, Sendable, Equatable {
        case work
        case nestingDepth
    }

    case sourceTooLarge(limit: Int, actual: Int)
    case resourceLimitExceeded(resource: Resource, limit: Int, actual: Int)
    case internalInvariant(message: String, location: SourceLocation?)

    public var errorDescription: String? {
        switch self {
        case let .sourceTooLarge(limit, actual):
            return "Markdown source contains \(actual) characters; the limit is \(limit)."
        case let .resourceLimitExceeded(resource, limit, actual):
            return "Markdown parsing exceeded the \(resource.rawValue) limit of \(limit) (actual: \(actual))."
        case let .internalInvariant(message, location):
            if let location {
                return "Markdown parser invariant failed at line \(location.line), column \(location.column): \(message)"
            }
            return "Markdown parser invariant failed: \(message)"
        }
    }
}

/// The main entry point for the Swift Markdown Parser.
///
/// This class provides methods to parse Markdown text into an AST that can
/// be consumed by various renderers for different output formats.
public final class SwiftMarkdownParser: Sendable {

    /// Deterministic resource policy applied independently to every parse.
    public struct ResourceLimits: Sendable, Equatable {
        public let maximumSourceLength: Int
        public let maximumNestingDepth: Int
        public let maximumWork: Int

        public init(
            maximumSourceLength: Int = 2_000_000,
            maximumNestingDepth: Int = 100,
            maximumWork: Int = 25_000_000
        ) {
            precondition(maximumSourceLength > 0, "maximumSourceLength must be positive")
            precondition(maximumNestingDepth > 0, "maximumNestingDepth must be positive")
            precondition(maximumWork > 0, "maximumWork must be positive")
            self.maximumSourceLength = maximumSourceLength
            self.maximumNestingDepth = maximumNestingDepth
            self.maximumWork = maximumWork
        }

        public static let `default` = ResourceLimits()
    }

    private let resourceLimits: ResourceLimits

    /// Creates a new instance of the markdown parser.
    /// - Parameter resourceLimits: Deterministic limits for each parse call.
    public init(resourceLimits: ResourceLimits = .default) {
        self.resourceLimits = resourceLimits
    }

    /// Parses the given Markdown text and returns an AST representation.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: A `DocumentNode` containing the parsed AST structure
    /// - Throws: `MarkdownParsingError` when a deterministic resource limit or
    ///   an internal construction invariant is violated. Incomplete Markdown
    ///   syntax is represented as literal text instead of an error.
    public func parse(_ markdown: String) throws -> AST.DocumentNode {
        let sourceLength = markdown.count
        guard sourceLength <= resourceLimits.maximumSourceLength else {
            throw MarkdownParsingError.sourceTooLarge(
                limit: resourceLimits.maximumSourceLength,
                actual: sourceLength
            )
        }

        let budget = ParsingBudget(
            maximumWork: resourceLimits.maximumWork,
            initialWork: sourceLength
        )
        let referenceResolution = ReferenceDefinitionResolver.resolve(in: markdown)
        let tokenizer = MarkdownTokenizer(
            referenceResolution.sourceForParsing,
            budget: budget
        )
        let tokenStream = TokenStream(tokenizer.tokenize(), budget: budget)

        let blockParser = BlockParser(
            tokenStream: tokenStream,
            limits: resourceLimits,
            budget: budget,
            source: markdown,
            linkReferences: referenceResolution.references
        )
        let document = try blockParser.parseDocument()
        try budget.validate()
        try MarkdownDocumentValidator.validate(document, sourceLength: sourceLength)
        return document
    }

    /// Convenience method to parse Markdown and render to HTML.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Parameter context: Rendering context for HTML output
    /// - Returns: HTML string representation
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTML(_ markdown: String, context: RenderContext = RenderContext()) async throws -> String {
        let ast = try parse(markdown)
        let htmlRenderer = HTMLRenderer(context: context)
        return try await htmlRenderer.render(document: ast)
    }

    /// Convenience method to parse Markdown and render to HTML with an enhanced dark Mermaid theme.
    /// This dark theme includes improved label visibility and contrast.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: HTML string representation with enhanced dark theme for Mermaid diagrams
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithDarkTheme(_ markdown: String) async throws -> String {
        let context = RenderContext(mermaidConfiguration: .dark)
        return try await parseToHTML(markdown, context: context)
    }

    /// Convenience method to parse Markdown and render to HTML with a high contrast dark Mermaid theme.
    /// This theme provides maximum visibility for labels and text elements.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: HTML string representation with high contrast dark theme for Mermaid diagrams
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithDarkHighContrastTheme(_ markdown: String) async throws -> String {
        let context = RenderContext(mermaidConfiguration: .darkHighContrast)
        return try await parseToHTML(markdown, context: context)
    }

    /// Convenience method to parse Markdown and render to HTML with a forest Mermaid theme.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: HTML string representation with forest theme for Mermaid diagrams
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithForestTheme(_ markdown: String) async throws -> String {
        let mermaidConfig = MermaidConfiguration(theme: .forest)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        return try await parseToHTML(markdown, context: context)
    }

    /// Convenience method to parse Markdown and render to HTML with a neutral Mermaid theme.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: HTML string representation with neutral theme for Mermaid diagrams
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithNeutralTheme(_ markdown: String) async throws -> String {
        let mermaidConfig = MermaidConfiguration(theme: .neutral)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        return try await parseToHTML(markdown, context: context)
    }

    /// Convenience method to parse Markdown and render to HTML with a base Mermaid theme.
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: HTML string representation with base theme for Mermaid diagrams
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithBaseTheme(_ markdown: String) async throws -> String {
        let mermaidConfig = MermaidConfiguration(theme: .base)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        return try await parseToHTML(markdown, context: context)
    }

    /// Convenience method to parse Markdown and render to HTML with KaTeX math rendering support.
    ///
    /// Uses default KaTeX configuration (CDN v0.16.21, throwOnError: false).
    ///
    /// - Parameter markdown: The Markdown text to parse
    /// - Returns: HTML string with KaTeX CSS/JS injected when math nodes are present
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithMath(_ markdown: String) async throws -> String {
        let context = RenderContext(katexConfiguration: .default)
        return try await parseToHTML(markdown, context: context)
    }

    /// Convenience method to parse Markdown and render to HTML with custom KaTeX configuration.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown text to parse
    ///   - katexConfiguration: Custom KaTeX configuration
    /// - Returns: HTML string with KaTeX CSS/JS injected when math nodes are present
    /// - Throws: `MarkdownParsingError` or `RendererError` if parsing or rendering fails
    public func parseToHTMLWithMath(_ markdown: String, katexConfiguration: KaTeXConfiguration) async throws -> String {
        let context = RenderContext(katexConfiguration: katexConfiguration)
        return try await parseToHTML(markdown, context: context)
    }
}

// MARK: - Enhanced HTML Renderer Implementation

/// Enhanced HTML renderer implementation with full feature support
public struct HTMLRenderer: MarkdownRenderer {
    public typealias Output = String

    internal let context: RenderContext

    public init(context: RenderContext = RenderContext()) {
        self.context = context
    }

    public func render(document: AST.DocumentNode) async throws -> String {
        var html = ""
        var mermaidDiagrams: [(node: AST.MermaidDiagramNode, id: String)] = []
        var hasMath = false

        // Single pre-pass: collect Mermaid diagrams and detect math nodes
        for visit in document.depthFirst() {
            if let mermaidNode = visit.node as? AST.MermaidDiagramNode {
                let id = MermaidUtils.generateSafeId(from: mermaidNode.content)
                mermaidDiagrams.append((node: mermaidNode, id: id))
            }
            if !hasMath && (visit.node is AST.MathBlockNode || visit.node is AST.InlineMathNode) {
                hasMath = true
            }
        }

        // Add Mermaid initialization if there are diagrams
        if !mermaidDiagrams.isEmpty && context.mermaidConfiguration.enabled {
            html += generateMermaidInitializationScript()
        }

        // Add KaTeX head content if math nodes are present
        if hasMath && context.katexConfiguration.enabled {
            html += katexRenderer.generateKaTeXHeadContent()
        }

        // Render all nodes
        for child in document.children {
            html += try await render(node: child)
        }

        // Add Mermaid rendering trigger at the end
        if !mermaidDiagrams.isEmpty && context.mermaidConfiguration.enabled {
            html += """
            <script>
            document.addEventListener('DOMContentLoaded', function() {
                if (typeof mermaid !== 'undefined') {
                    mermaid.init();
                }
            });
            </script>
            """
        }

        return html
    }

    /// Shared KaTeX renderer instance, created once per HTMLRenderer
    private var katexRenderer: KaTeXRenderer {
        KaTeXRenderer(configuration: context.katexConfiguration)
    }

    private func generateMermaidInitializationScript() -> String {
        switch context.mermaidConfiguration.renderMode {
        case .embedded:
            return """
            <script>
            \(MermaidRenderer.embeddedMermaidJS)
            </script>
            <script>
            \(context.mermaidConfiguration.generateInitScript())
            </script>
            """

        case .cdn(let version):
            return """
            <script src="https://cdn.jsdelivr.net/npm/mermaid@\(version)/dist/mermaid.min.js"></script>
            <script>
            \(context.mermaidConfiguration.generateInitScript())
            </script>
            """

        case .custom(let url):
            return """
            <script src="\(url)"></script>
            <script>
            \(context.mermaidConfiguration.generateInitScript())
            </script>
            """
        }
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
            let renderer = HTMLRenderer(context: context)
            return try await renderer.renderGFMTable(tableNode)

        case let taskListItemNode as AST.GFMTaskListItemNode:
            return try await renderGFMTaskListItem(taskListItemNode)

        // Mermaid Support
        case let mermaidNode as AST.MermaidDiagramNode:
            return renderMermaidDiagram(mermaidNode)

        // Footnote Support
        case let footnoteRefNode as AST.FootnoteReferenceNode:
            return renderFootnoteReference(footnoteRefNode)

        case let footnoteDefNode as AST.FootnoteDefinitionNode:
            return try await renderFootnoteDefinition(footnoteDefNode)

        // Math Support
        case let mathBlockNode as AST.MathBlockNode:
            return katexRenderer.renderMathBlock(mathBlockNode)

        case let inlineMathNode as AST.InlineMathNode:
            return katexRenderer.renderInlineMath(inlineMathNode)

        default:
            throw RendererError.unsupportedNodeType(node.nodeType)
        }
    }

    private func renderMermaidDiagram(_ mermaidNode: AST.MermaidDiagramNode) -> String {
        let mermaidRenderer = MermaidRenderer(configuration: context.mermaidConfiguration)
        return mermaidRenderer.renderMermaidDiagram(mermaidNode)
    }

    private func renderFootnoteReference(_ footnoteRefNode: AST.FootnoteReferenceNode) -> String {
        let attributes = RendererUtils.htmlAttributes(
            for: .footnoteReference,
            sourceLocation: footnoteRefNode.sourceLocation,
            styleConfig: context.styleConfiguration
        )

        return "<a href=\"#fn\(footnoteRefNode.identifier)\" class=\"footnote\" id=\"fnref\(footnoteRefNode.identifier)\"\(RendererUtils.formatHTMLAttributes(attributes))>\(footnoteRefNode.identifier)</a>"
    }

    private func renderFootnoteDefinition(_ footnoteDefNode: AST.FootnoteDefinitionNode) async throws -> String {
        var content = ""
        for child in footnoteDefNode.children {
            content += try await render(node: child)
        }

        let attributes = RendererUtils.htmlAttributes(
            for: .footnoteDefinition,
            sourceLocation: footnoteDefNode.sourceLocation,
            styleConfig: context.styleConfiguration
        )

        return "<div class=\"footnote-definition\" id=\"fn\(footnoteDefNode.identifier)\"\(RendererUtils.formatHTMLAttributes(attributes))>\(content)<a href=\"#fnref\(footnoteDefNode.identifier)\" class=\"footnote-backref\">↩</a></div>"
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
