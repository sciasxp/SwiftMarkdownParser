/// KaTeX math renderer for converting math AST nodes to HTML
///
/// This renderer provides HTML generation for math expressions with support
/// for KaTeX library loading via CDN or custom URLs.

import Foundation

// MARK: - KaTeX Renderer

/// Renderer for math expression nodes
public struct KaTeXRenderer {

    /// Configuration for KaTeX rendering
    public let configuration: KaTeXConfiguration

    /// Initialize with configuration
    public init(configuration: KaTeXConfiguration = .default) {
        self.configuration = configuration
    }

    /// Render a math block node to HTML with KaTeX container
    public func renderMathBlock(_ node: AST.MathBlockNode) -> String {
        return renderMath(content: node.content, isDisplay: true)
    }

    /// Render an inline math node to HTML
    public func renderInlineMath(_ node: AST.InlineMathNode) -> String {
        return renderMath(content: node.content, isDisplay: false)
    }

    /// Render math content to HTML with appropriate container element and CSS classes
    private func renderMath(content: String, isDisplay: Bool) -> String {
        let escaped = RendererUtils.escapeHTML(content)
        let displayClass = isDisplay ? KaTeXCSS.mathDisplay : KaTeXCSS.mathInline
        let cssClasses = "\(KaTeXCSS.mathBase) \(displayClass)"
        if isDisplay {
            return "<div class=\"\(cssClasses)\">\(escaped)</div>\n"
        } else {
            return "<span class=\"\(cssClasses)\">\(escaped)</span>"
        }
    }

    /// Generate all KaTeX head content (CSS + JS + init script)
    public func generateKaTeXHeadContent() -> String {
        guard configuration.enabled else {
            return ""
        }

        var html = ""

        // 1. CSS stylesheet
        html += configuration.generateStylesheetLink() + "\n"

        // 2. JS script
        html += configuration.generateScriptTags() + "\n"

        // 3. Init script
        html += "<script>\n"
        html += configuration.generateInitScript()
        html += "\n</script>\n"

        return html
    }

    /// Generate a standalone HTML document with math support
    public func generateStandaloneHTML(content: String, title: String = "Math Document") -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 900px;
                    margin: 0 auto;
                    padding: 20px;
                }
                .math-display {
                    text-align: center;
                    margin: 1em 0;
                }
                \(configuration.customCSS ?? "")
            </style>
            \(generateKaTeXHeadContent())
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
}
