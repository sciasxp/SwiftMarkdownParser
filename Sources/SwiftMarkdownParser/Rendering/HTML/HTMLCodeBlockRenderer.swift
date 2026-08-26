/// Owns HTML-specific presentation of code blocks while delegating language
/// selection, fallback, token validation, and caching to `SyntaxHighlighter`.
struct HTMLCodeBlockRenderer: Sendable {
    let styleConfiguration: HTMLStyleConfiguration
    let highlighter: SyntaxHighlighter

    func render(_ node: AST.CodeBlockNode) async -> String {
        let language = node.language
        let content: String

        if styleConfiguration.syntaxHighlighting.enabled,
           let language,
           let tokens = await highlighter.highlight(node.content, language: language) {
            content = render(tokens, source: node.content)
        } else {
            content = RendererUtils.escapeHTML(node.content)
        }

        var codeAttributes: [String: String] = [:]
        if let language {
            codeAttributes["class"] = "language-" + language
        }

        let preAttributes = RendererUtils.htmlAttributes(
            for: .codeBlock,
            sourceLocation: node.sourceLocation,
            styleConfig: styleConfiguration
        )

        return "<pre\(RendererUtils.formatHTMLAttributes(preAttributes))>" +
            "<code\(RendererUtils.formatHTMLAttributes(codeAttributes))>" +
            "\(content)</code></pre>\n"
    }

    private func render(_ tokens: [SyntaxToken], source: String) -> String {
        var html = ""
        var currentIndex = source.startIndex

        for token in tokens {
            if currentIndex < token.range.lowerBound {
                html += RendererUtils.escapeHTML(String(source[currentIndex..<token.range.lowerBound]))
            }

            let attributes = [
                "class": styleConfiguration.syntaxHighlighting.cssPrefix + token.tokenType.rawValue,
            ]
            html += "<span\(RendererUtils.formatHTMLAttributes(attributes))>" +
                "\(RendererUtils.escapeHTML(token.content))</span>"
            currentIndex = token.range.upperBound
        }

        if currentIndex < source.endIndex {
            html += RendererUtils.escapeHTML(String(source[currentIndex..<source.endIndex]))
        }

        return html
    }
}
