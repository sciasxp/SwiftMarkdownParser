/// Internal Mermaid implementation used by HTML-backed output.
///
/// This renderer provides HTML generation for Mermaid diagrams with support
/// for both embedded and CDN-based Mermaid.js loading.

import Foundation

// MARK: - Mermaid Renderer

/// Renderer for Mermaid diagram nodes
struct MermaidRenderer {

    /// Configuration for Mermaid rendering
    let configuration: MermaidConfiguration

    /// Initialize with configuration
    init(configuration: MermaidConfiguration = .default) {
        self.configuration = configuration
    }

    /// Render a Mermaid diagram node to HTML
    func renderMermaidDiagram(_ node: AST.MermaidDiagramNode, id: String? = nil) -> String {
        guard configuration.enabled else {
            // If Mermaid is disabled, render as a regular code block
            return renderAsCodeBlock(node)
        }

        let diagramId = id ?? generateDiagramId()

        return """
        <div class="mermaid-container" id="\(diagramId)-container">
            <pre class="mermaid" id="\(diagramId)">\(node.content)</pre>
        </div>
        """
    }

    /// Generates the resources required in a complete HTML document's head.
    func generateHeadContent() -> String {
        guard configuration.enabled else {
            return ""
        }

        return """
        \(generateMermaidScript())
        <script>
        \(configuration.generateInitScript())
        </script>
        """
    }

    // MARK: - Private Methods

    /// Render diagram as a code block (fallback when Mermaid is disabled)
    private func renderAsCodeBlock(_ node: AST.MermaidDiagramNode) -> String {
        let escaped = RendererUtils.escapeHTML(node.content)
        return """
        <pre><code class="language-mermaid">\(escaped)</code></pre>
        """
    }

    /// Generate a unique diagram ID
    private func generateDiagramId() -> String {
        return "\(configuration.htmlIdPrefix)\(UUID().uuidString.prefix(8))"
    }

    /// Generate Mermaid script tag based on render mode
    private func generateMermaidScript() -> String {
        switch configuration.renderMode {
        case .embedded:
            return """
            <script>
            \(Self.embeddedMermaidJS)
            </script>
            """

        case .cdn(let version):
            return """
            <script src="https://cdn.jsdelivr.net/npm/mermaid@\(version)/dist/mermaid.min.js"></script>
            """

        case .custom(let url):
            return """
            <script src="\(url)"></script>
            """
        }
    }

    /// Embedded Mermaid.js loader
    /// This is a placeholder - in production, you would embed the actual minified Mermaid.js
    /// For now, we'll use CDN fallback with a simple loader
    static let embeddedMermaidJS = """
    // Mermaid.js Embedded Loader
    // This is a lightweight loader that fetches Mermaid.js if not already loaded
    (function() {
        if (typeof window.mermaid !== 'undefined') {
            return; // Mermaid already loaded
        }

        // Create a simple Mermaid stub that will queue diagrams until the real library loads
        window.mermaid = {
            _queue: [],
            _initialized: false,

            init: function(config) {
                if (this._initialized) {
                    this._realInit(config);
                } else {
                    this._queue.push(['init', config]);
                }
            },

            initialize: function(config) {
                if (this._initialized) {
                    this._realInitialize(config);
                } else {
                    this._queue.push(['initialize', config]);
                }
            },

            render: function(id, text, callback) {
                if (this._initialized) {
                    this._realRender(id, text, callback);
                } else {
                    this._queue.push(['render', id, text, callback]);
                }
            }
        };

        // Load Mermaid.js from CDN as fallback
        var script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js';
        script.onload = function() {
            // Store real methods
            var realMermaid = window.mermaid;
            var stub = window.mermaid;

            // Replace stub with real mermaid
            window.mermaid = realMermaid;
            window.mermaid._realInit = realMermaid.init;
            window.mermaid._realInitialize = realMermaid.initialize;
            window.mermaid._realRender = realMermaid.render;

            // Process queued calls
            stub._queue.forEach(function(call) {
                var method = call[0];
                var args = call.slice(1);
                realMermaid[method].apply(realMermaid, args);
            });

            stub._initialized = true;
        };

        script.onerror = function() {
            console.error('Failed to load Mermaid.js from CDN');
            // Provide fallback rendering as code blocks
            document.querySelectorAll('.mermaid').forEach(function(el) {
                var pre = document.createElement('pre');
                var code = document.createElement('code');
                code.className = 'language-mermaid';
                code.textContent = el.textContent;
                pre.appendChild(code);
                el.parentNode.replaceChild(pre, el);
            });
        };

        document.head.appendChild(script);
    })();
    """
}
