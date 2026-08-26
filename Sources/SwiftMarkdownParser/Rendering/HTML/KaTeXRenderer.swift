/// Produces semantic math containers consumed by the browser-document runtime.
struct KaTeXRenderer {
    let configuration: KaTeXConfiguration

    init(configuration: KaTeXConfiguration = .default) {
        self.configuration = configuration
    }

    func renderMathBlock(_ node: AST.MathBlockNode) -> String {
        renderMath(content: node.content, isDisplay: true)
    }

    func renderInlineMath(_ node: AST.InlineMathNode) -> String {
        renderMath(content: node.content, isDisplay: false)
    }

    private func renderMath(content: String, isDisplay: Bool) -> String {
        let escaped = RendererUtils.escapeHTML(content)
        let displayClass = isDisplay ? KaTeXCSS.mathDisplay : KaTeXCSS.mathInline
        let classes = "\(KaTeXCSS.mathBase) \(displayClass)"

        if isDisplay {
            return "<div class=\"\(classes)\">\(escaped)</div>\n"
        }
        return "<span class=\"\(classes)\">\(escaped)</span>"
    }
}
