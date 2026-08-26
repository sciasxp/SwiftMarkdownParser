/// Internal KaTeX implementation used by the HTML output module.
///
/// This renderer provides HTML generation for math expressions with support
/// for KaTeX library loading via CDN or custom URLs.

import Foundation

// MARK: - KaTeX Renderer

/// Renderer for math expression nodes
struct KaTeXRenderer {

    /// Configuration for KaTeX rendering
    let configuration: KaTeXConfiguration

    /// Initialize with configuration
    init(configuration: KaTeXConfiguration = .default) {
        self.configuration = configuration
    }

    /// Render a math block node to HTML with KaTeX container
    func renderMathBlock(_ node: AST.MathBlockNode) -> String {
        return renderMath(content: node.content, isDisplay: true)
    }

    /// Render an inline math node to HTML
    func renderInlineMath(_ node: AST.InlineMathNode) -> String {
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
    func generateKaTeXHeadContent() -> String {
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

}
