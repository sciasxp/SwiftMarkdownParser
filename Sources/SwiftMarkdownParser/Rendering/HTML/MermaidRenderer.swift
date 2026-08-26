import Foundation

/// Produces the semantic container consumed by the browser-document runtime.
struct MermaidRenderer {
    let configuration: MermaidConfiguration

    init(configuration: MermaidConfiguration = .default) {
        self.configuration = configuration
    }

    func render(_ node: AST.MermaidDiagramNode, id: String? = nil) -> String {
        guard configuration.enabled else {
            return renderFallback(node)
        }

        let diagramID = id ?? "\(configuration.htmlIdPrefix)\(UUID().uuidString.prefix(8))"
        let escapedContent = RendererUtils.escapeHTML(node.content)
        let escapedID = RendererUtils.escapeHTMLAttribute(diagramID)

        return """
        <div class="mermaid-container" id="\(escapedID)-container">
            <pre class="mermaid" id="\(escapedID)">\(escapedContent)</pre>
        </div>
        """
    }

    private func renderFallback(_ node: AST.MermaidDiagramNode) -> String {
        """
        <pre><code class="language-mermaid">\(RendererUtils.escapeHTML(node.content))</code></pre>
        """
    }
}
