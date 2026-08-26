import Foundation

/// Renders complete Markdown documents to HTML while owning all HTML-specific
/// escaping, feature assets, styling, and document composition.
public struct HTMLRenderer: Sendable {
    let options: HTMLRenderOptions

    public init(options: HTMLRenderOptions = .init()) {
        self.options = options
    }

    /// Produces a self-contained embeddable fragment.
    public func renderFragment(_ document: AST.DocumentNode) async throws -> String {
        let parts = try await renderParts(document)
        return parts.head + parts.body + parts.trailingBody
    }

    /// Produces a complete HTML document with resources placed in the correct section.
    public func renderDocument(
        _ document: AST.DocumentNode,
        metadata: HTMLDocumentMetadata = .init()
    ) async throws -> String {
        let parts = try await renderParts(document)
        return HTMLDocumentTemplate.render(
            head: parts.head,
            body: parts.body,
            trailingBody: parts.trailingBody,
            metadata: metadata
        )
    }

    private func renderParts(_ document: AST.DocumentNode) async throws -> HTMLRenderParts {
        var hasMermaid = false
        var hasMath = false

        for visit in document.depthFirst() {
            hasMermaid = hasMermaid || visit.node is AST.MermaidDiagramNode
            if !hasMath && (visit.node is AST.MathBlockNode || visit.node is AST.InlineMathNode) {
                hasMath = true
            }
        }

        var head = ""
        if hasMermaid && options.mermaidConfiguration.enabled {
            head += mermaidRenderer.generateHeadContent()
        }
        if hasMath && options.katexConfiguration.enabled {
            head += katexRenderer.generateKaTeXHeadContent()
        }

        var body = ""
        for child in document.children {
            body += try await render(node: child)
        }

        var trailingBody = ""
        if hasMermaid && options.mermaidConfiguration.enabled {
            trailingBody = """
            <script>
            document.addEventListener('DOMContentLoaded', function() {
                if (typeof mermaid !== 'undefined') {
                    mermaid.init();
                }
            });
            </script>
            """
        }

        return HTMLRenderParts(head: head, body: body, trailingBody: trailingBody)
    }

    /// Shared KaTeX renderer instance, created once per HTMLRenderer
    private var katexRenderer: KaTeXRenderer {
        KaTeXRenderer(configuration: options.katexConfiguration)
    }

    private var mermaidRenderer: MermaidRenderer {
        MermaidRenderer(configuration: options.mermaidConfiguration)
    }

    func render(node: ASTNode) async throws -> String {
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
            )
            return "<del\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</del>"

        case let linkNode as AST.LinkNode:
            var content = ""
            for child in linkNode.children {
                content += try await render(node: child)
            }

            guard let normalizedURL = RendererUtils.normalizeURL(linkNode.url, baseURL: options.baseURL) else {
                // If URL is invalid/unsafe, render as plain text
                return content
            }

            var attributes = RendererUtils.htmlAttributes(
                for: .link,
                sourceLocation: linkNode.sourceLocation,
                styleConfig: options.styleConfiguration
            )
            attributes["href"] = normalizedURL

            if let title = linkNode.title {
                attributes["title"] = title
            }

            return "<a\(RendererUtils.formatHTMLAttributes(attributes))>\(content)</a>"

        case let imageNode as AST.ImageNode:
            let altText = imageNode.altText

            guard let normalizedURL = RendererUtils.normalizeURL(imageNode.url, baseURL: options.baseURL) else {
                // If URL is invalid/unsafe, render alt text
                return RendererUtils.escapeHTML(altText)
            }

            var attributes = RendererUtils.htmlAttributes(
                for: .image,
                sourceLocation: imageNode.sourceLocation,
                styleConfig: options.styleConfiguration
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
                styleConfig: options.styleConfiguration
            )
            return "<code\(RendererUtils.formatHTMLAttributes(attributes))>\(RendererUtils.escapeHTML(codeSpanNode.content))</code>"

        case let lineBreakNode as AST.LineBreakNode:
            return lineBreakNode.isHard ? "<br />\n" : "\n"

        case _ as AST.SoftBreakNode:
            return " "

        case let autolinkNode as AST.AutolinkNode:
            let url = autolinkNode.url
            let text = autolinkNode.text
            guard let normalizedURL = RendererUtils.normalizeURL(url, baseURL: options.baseURL) else {
                return RendererUtils.escapeHTML(text)
            }
            var attributes = RendererUtils.htmlAttributes(
                for: .autolink,
                sourceLocation: autolinkNode.sourceLocation,
                styleConfig: options.styleConfiguration
            )
            attributes["href"] = normalizedURL
            return "<a\(RendererUtils.formatHTMLAttributes(attributes))>\(RendererUtils.escapeHTML(text))</a>"

        case let htmlBlockNode as AST.HTMLBlockNode:
            if options.sanitizeHTML {
                return RendererUtils.escapeHTML(htmlBlockNode.content)
            }
            return htmlBlockNode.content

        case let htmlInlineNode as AST.HTMLInlineNode:
            if options.sanitizeHTML {
                return RendererUtils.escapeHTML(htmlInlineNode.content)
            }
            return htmlInlineNode.content

        // GFM Extensions
        case let tableNode as AST.GFMTableNode:
            return try await renderGFMTable(tableNode)

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
            throw HTMLRenderingError.unsupportedNodeType(node.nodeType)
        }
    }

    private func renderMermaidDiagram(_ mermaidNode: AST.MermaidDiagramNode) -> String {
        let mermaidRenderer = MermaidRenderer(configuration: options.mermaidConfiguration)
        return mermaidRenderer.renderMermaidDiagram(mermaidNode)
    }

    private func renderFootnoteReference(_ footnoteRefNode: AST.FootnoteReferenceNode) -> String {
        let attributes = RendererUtils.htmlAttributes(
            for: .footnoteReference,
            sourceLocation: footnoteRefNode.sourceLocation,
            styleConfig: options.styleConfiguration
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
            styleConfig: options.styleConfiguration
        )

        return "<div class=\"footnote-definition\" id=\"fn\(footnoteDefNode.identifier)\"\(RendererUtils.formatHTMLAttributes(attributes))>\(content)<a href=\"#fnref\(footnoteDefNode.identifier)\" class=\"footnote-backref\">↩</a></div>"
    }

    private func renderCodeBlock(_ codeBlockNode: AST.CodeBlockNode) async throws -> String {
        let language = codeBlockNode.language
        let content = codeBlockNode.content

        // Check if syntax highlighting is enabled and we have a language
        if let language = language,
           options.styleConfiguration.syntaxHighlighting.enabled,
           options.styleConfiguration.syntaxHighlighting.supportedLanguages.contains(language.lowercased()) {

            // Use syntax highlighting engine
            let registry = SyntaxHighlightingRegistry()
            if let engine = await registry.engine(for: language) {
                do {
                    let tokens = try await engine.highlight(content, language: language)
                    let highlightedHTML = renderSyntaxTokensToHTML(tokens, originalCode: content, cssPrefix: options.styleConfiguration.syntaxHighlighting.cssPrefix)

                    var codeAttributes: [String: String] = [:]
                    codeAttributes["class"] = "language-" + language

                    let preAttributes = RendererUtils.htmlAttributes(
                        for: .codeBlock,
                        sourceLocation: codeBlockNode.sourceLocation,
                        styleConfig: options.styleConfiguration
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
            styleConfig: options.styleConfiguration
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

private struct HTMLRenderParts {
    let head: String
    let body: String
    let trailingBody: String
}
