/// WebView support for rendering Mermaid diagrams
/// 
/// This file provides WebView integration for displaying Mermaid diagrams
/// in SwiftUI and UIKit/AppKit applications.

#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

// MARK: - WebView Support for SwiftUI

/// SwiftUI view for displaying general markdown content in a WebView
@available(iOS 17.0, macOS 14.0, *)
public struct MarkdownWebView: View {
    
    /// The markdown content to render
    public let markdownContent: String
    
    /// Configuration for markdown parsing
    public let configuration: SwiftMarkdownParser.Configuration
    
    /// Optional callback when content is rendered
    public let onRender: ((Result<Void, Error>) -> Void)?
    
    /// Whether to include math support
    public let includeMathSupport: Bool
    
    /// Whether to include task list support
    public let includeTaskListSupport: Bool
    
    /// State for the WebView
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var error: Error?
    
    public init(
        markdownContent: String,
        configuration: SwiftMarkdownParser.Configuration = SwiftMarkdownParser.Configuration(),
        includeMathSupport: Bool = true,
        includeTaskListSupport: Bool = true,
        onRender: ((Result<Void, Error>) -> Void)? = nil
    ) {
        self.markdownContent = markdownContent
        self.configuration = configuration
        self.includeMathSupport = includeMathSupport
        self.includeTaskListSupport = includeTaskListSupport
        self.onRender = onRender
    }
    
    public var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            MarkdownWebViewRepresentable(
                markdownContent: markdownContent,
                configuration: configuration,
                includeMathSupport: includeMathSupport,
                includeTaskListSupport: includeTaskListSupport,
                isLoading: $isLoading,
                error: $error,
                onRender: onRender
            )
            .opacity(isLoading ? 0 : 1)
            
            if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("Failed to render markdown")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// SwiftUI view for displaying Mermaid diagrams in a WebView
@available(iOS 17.0, macOS 14.0, *)
public struct MermaidWebView: View {
    
    /// The Mermaid diagram node to render
    public let diagramNode: AST.MermaidDiagramNode
    
    /// Configuration for Mermaid rendering
    public let configuration: MermaidConfiguration
    
    /// Optional callback when diagram is rendered
    public let onRender: ((Result<Void, Error>) -> Void)?
    
    /// State for the WebView
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var error: Error?
    
    public init(
        diagramNode: AST.MermaidDiagramNode,
        configuration: MermaidConfiguration = .default,
        onRender: ((Result<Void, Error>) -> Void)? = nil
    ) {
        self.diagramNode = diagramNode
        self.configuration = configuration
        self.onRender = onRender
    }
    
    public var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            MermaidWebViewRepresentable(
                diagramNode: diagramNode,
                configuration: configuration,
                isLoading: $isLoading,
                error: $error,
                onRender: onRender
            )
            .opacity(isLoading ? 0 : 1)
            
            if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("Failed to render diagram")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - WebView Representable

@available(iOS 17.0, macOS 14.0, *)
struct MarkdownWebViewRepresentable: NSViewRepresentable {
    let markdownContent: String
    let configuration: SwiftMarkdownParser.Configuration
    let includeMathSupport: Bool
    let includeTaskListSupport: Bool
    @Binding var isLoading: Bool
    @Binding var error: Error?
    let onRender: ((Result<Void, Error>) -> Void)?
    
    @MainActor
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        
        // Set up message handler for JavaScript communication
        webConfiguration.userContentController.add(
            context.coordinator,
            name: "markdownHandler"
        )
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    @MainActor
    func updateNSView(_ webView: WKWebView, context: Context) {
        Task {
            await loadMarkdownContent(in: webView)
        }
    }
    
    @MainActor
    func makeCoordinator() -> MarkdownCoordinator {
        MarkdownCoordinator(parent: self)
    }
    
    @MainActor
    private func loadMarkdownContent(in webView: WKWebView) async {
        do {
            let html = try await WebViewSupport.generateMarkdownHTMLDocument(
                markdownContent,
                title: "Markdown Document",
                configuration: configuration,
                includeMathSupport: includeMathSupport,
                includeTaskListSupport: includeTaskListSupport
            )
            
            webView.loadHTMLString(html, baseURL: nil)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = error
                self.onRender?(.failure(error))
            }
        }
    }
    
    class MarkdownCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MarkdownWebViewRepresentable
        
        @MainActor
        init(parent: MarkdownWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.onRender?(.success(()))
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.error = error
            parent.onRender?(.failure(error))
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "markdownHandler" {
                print("Markdown message received: \(message.body)")
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct MermaidWebViewRepresentable: NSViewRepresentable {
    let diagramNode: AST.MermaidDiagramNode
    let configuration: MermaidConfiguration
    @Binding var isLoading: Bool
    @Binding var error: Error?
    let onRender: ((Result<Void, Error>) -> Void)?
    
    @MainActor
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        // JavaScript is enabled by default in modern WebKit
        
        // Set up message handler for JavaScript communication
        webConfiguration.userContentController.add(
            context.coordinator,
            name: "mermaidHandler"
        )
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    @MainActor
    func updateNSView(_ webView: WKWebView, context: Context) {
        loadMermaidContent(in: webView)
    }
    
    @MainActor
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    @MainActor
    private func loadMermaidContent(in webView: WKWebView) {
        let renderer = MermaidRenderer(configuration: configuration)
        let html = renderer.generateStandaloneHTML(
            content: renderer.renderMermaidDiagram(diagramNode),
            title: "Mermaid Diagram"
        )
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MermaidWebViewRepresentable
        
        @MainActor
        init(parent: MermaidWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.onRender?(.success(()))
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.error = error
            parent.onRender?(.failure(error))
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Handle messages from JavaScript if needed
            if message.name == "mermaidHandler" {
                // Process Mermaid-related messages
                print("Mermaid message received: \(message.body)")
            }
        }
    }
}

// MARK: - WebView HTML Generator

/// Utilities for generating WebView-compatible HTML for all markdown content
public enum WebViewSupport {
    
    /// Generate complete HTML document for general markdown content
    public static func generateMarkdownHTMLDocument(
        _ markdownContent: String,
        title: String = "Markdown Document",
        configuration: SwiftMarkdownParser.Configuration = SwiftMarkdownParser.Configuration(),
        includeMathSupport: Bool = true,
        includeTaskListSupport: Bool = true
    ) async throws -> String {
        let parser = SwiftMarkdownParser(configuration: configuration)
        let ast = try await parser.parseToAST(markdownContent)
        
        // Create enhanced render context with proper styling
        let styleConfig = StyleConfiguration(
            cssClasses: [:],
            customAttributes: [:],
            includeSourcePositions: false,
            syntaxHighlighting: SyntaxHighlightingConfig(enabled: true)
        )
        
        let context = RenderContext(
            baseURL: nil,
            sanitizeHTML: true,
            styleConfiguration: styleConfig,
            mermaidConfiguration: .default
        )
        
        let htmlRenderer = HTMLRenderer(context: context, configuration: configuration)
        let bodyContent = try await htmlRenderer.render(document: ast)
        
        return generateStandaloneMarkdownHTML(
            content: bodyContent,
            title: title,
            includeMathSupport: includeMathSupport,
            includeTaskListSupport: includeTaskListSupport
        )
    }
    
    /// Generate complete HTML document for Mermaid diagrams
    public static func generateHTMLDocument(
        for nodes: [AST.MermaidDiagramNode],
        configuration: MermaidConfiguration = .default,
        includeInteractiveFeatures: Bool = true
    ) -> String {
        let renderer = MermaidRenderer(configuration: configuration)
        
        var diagramsHTML = ""
        for node in nodes {
            diagramsHTML += renderer.renderMermaidDiagram(node)
            diagramsHTML += "\n"
        }
        
        var interactiveScript = ""
        if includeInteractiveFeatures {
            interactiveScript = generateInteractiveScript()
        }
        
        return renderer.generateStandaloneHTML(
            content: diagramsHTML + interactiveScript,
            title: "Mermaid Diagrams"
        )
    }
    
    /// Generate standalone HTML with comprehensive markdown styling
    private static func generateStandaloneMarkdownHTML(
        content: String,
        title: String,
        includeMathSupport: Bool = true,
        includeTaskListSupport: Bool = true
    ) -> String {
        var mathScripts = ""
        if includeMathSupport {
            mathScripts = generateMathSupport()
        }
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            \(generateMarkdownCSS())
            \(mathScripts)
        </head>
        <body>
            <div class="markdown-content">
                \(content)
            </div>
            \(generateFootnoteScript())
            \(generateTaskListScript())
        </body>
        </html>
        """
    }
    
    /// Generate comprehensive CSS for markdown elements
    private static func generateMarkdownCSS() -> String {
        return """
        <style>
        /* Base styling */
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #fff;
            margin: 0;
            padding: 0;
        }
        
        .markdown-content {
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
        }
        
        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
            line-height: 1.25;
        }
        
        h1 {
            font-size: 2em;
            border-bottom: 1px solid #eaecef;
            padding-bottom: 0.3em;
        }
        
        h2 {
            font-size: 1.5em;
            border-bottom: 1px solid #eaecef;
            padding-bottom: 0.3em;
        }
        
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #6a737d; }
        
        /* Paragraphs */
        p {
            margin-top: 0;
            margin-bottom: 16px;
        }
        
        /* Lists */
        ul, ol {
            padding-left: 2em;
            margin-top: 0;
            margin-bottom: 16px;
        }
        
        ul ul, ul ol, ol ol, ol ul {
            margin-top: 0;
            margin-bottom: 0;
        }
        
        li {
            margin: 0.25em 0;
        }
        
        li > p {
            margin-top: 16px;
        }
        
        li + li {
            margin-top: 0.25em;
        }
        
        /* Task Lists */
        ul.task-list {
            list-style: none;
            padding-left: 0;
        }
        
        .task-list-item {
            display: flex;
            align-items: flex-start;
            margin: 8px 0;
            padding: 4px 8px;
            border-radius: 6px;
        }
        
        .task-list-item-checked {
            background-color: rgba(33, 136, 33, 0.08);
        }
        
        .task-list-checkbox {
            margin-right: 8px;
            margin-top: 2px;
            transform: scale(1.2);
            flex-shrink: 0;
        }
        
        .task-list-checkbox-checked {
            accent-color: #218838;
        }
        
        .task-list-content-checked {
            opacity: 0.8;
            text-decoration: line-through;
            text-decoration-color: #218838;
        }
        
        /* Code */
        code {
            background-color: rgba(175, 184, 193, 0.2);
            border-radius: 6px;
            font-size: 85%;
            margin: 0;
            padding: 0.2em 0.4em;
            font-family: 'SF Mono', Monaco, Inconsolata, 'Roboto Mono', 'Source Code Pro', monospace;
        }
        
        pre {
            background-color: #f6f8fa;
            border-radius: 6px;
            font-size: 85%;
            line-height: 1.45;
            overflow: auto;
            padding: 16px;
            margin-bottom: 16px;
        }
        
        pre code {
            background-color: transparent;
            border: 0;
            display: inline;
            line-height: inherit;
            margin: 0;
            max-width: auto;
            overflow: visible;
            padding: 0;
            word-wrap: normal;
        }
        
        /* Blockquotes */
        blockquote {
            border-left: 0.25em solid #dfe2e5;
            color: #6a737d;
            margin: 0;
            padding: 0 1em;
            margin-bottom: 16px;
        }
        
        blockquote > :first-child {
            margin-top: 0;
        }
        
        blockquote > :last-child {
            margin-bottom: 0;
        }
        
        /* Tables */
        table {
            border-spacing: 0;
            border-collapse: collapse;
            margin-bottom: 16px;
            width: 100%;
        }
        
        table th {
            font-weight: 600;
            background-color: #f6f8fa;
        }
        
        table th, table td {
            padding: 6px 13px;
            border: 1px solid #dfe2e5;
        }
        
        table tr {
            background-color: #fff;
            border-top: 1px solid #c6cbd1;
        }
        
        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }
        
        /* Links */
        a {
            color: #0366d6;
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-style: none;
            box-sizing: content-box;
        }
        
        /* Horizontal Rules */
        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: #e1e4e8;
            border: 0;
        }
        
        /* Emphasis */
        em {
            font-style: italic;
        }
        
        strong {
            font-weight: 600;
        }
        
        del {
            text-decoration: line-through;
        }
        
        /* Footnotes */
        .footnote {
            font-size: 0.9em;
            color: #0366d6;
            text-decoration: none;
            vertical-align: super;
        }
        
        .footnote:hover {
            text-decoration: underline;
        }
        
        .footnotes {
            border-top: 1px solid #eaecef;
            margin-top: 2em;
            padding-top: 1em;
            font-size: 0.9em;
        }
        
        .footnotes ol {
            padding-left: 1.5em;
        }
        
        .footnotes li {
            margin: 0.5em 0;
        }
        
        /* Math */
        .math {
            font-family: 'Latin Modern Math', 'Times New Roman', serif;
        }
        
        .math-display {
            text-align: center;
            margin: 1em 0;
        }
        
        /* Syntax highlighting */
        .language-swift .keyword { color: #a626a4; }
        .language-swift .string { color: #50a14f; }
        .language-swift .comment { color: #a0a1a7; font-style: italic; }
        .language-swift .number { color: #986801; }
        .language-swift .type { color: #0184bc; }
        
        .language-javascript .keyword { color: #d73a49; }
        .language-javascript .string { color: #032f62; }
        .language-javascript .comment { color: #6a737d; font-style: italic; }
        .language-javascript .number { color: #005cc5; }
        
        .language-python .keyword { color: #d73a49; }
        .language-python .string { color: #032f62; }
        .language-python .comment { color: #6a737d; font-style: italic; }
        .language-python .number { color: #005cc5; }
        
        /* Dark mode support */
        @media (prefers-color-scheme: dark) {
            body {
                background-color: #0d1117;
                color: #c9d1d9;
            }
            
            h1, h2 {
                border-bottom-color: #21262d;
            }
            
            h6 {
                color: #8b949e;
            }
            
            code {
                background-color: rgba(110, 118, 129, 0.4);
            }
            
            pre {
                background-color: #161b22;
            }
            
            blockquote {
                border-left-color: #30363d;
                color: #8b949e;
            }
            
            table th {
                background-color: #161b22;
            }
            
            table th, table td {
                border-color: #30363d;
            }
            
            table tr {
                background-color: #0d1117;
                border-top-color: #21262d;
            }
            
            table tr:nth-child(2n) {
                background-color: #161b22;
            }
            
            a {
                color: #58a6ff;
            }
            
            hr {
                background-color: #21262d;
            }
            
            .footnotes {
                border-top-color: #21262d;
            }
            
            .task-list-item-checked {
                background-color: rgba(46, 160, 67, 0.15);
            }
        }
        </style>
        """
    }
    
    /// Generate math rendering support with KaTeX
    private static func generateMathSupport() -> String {
        return """
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>
        <script>
        document.addEventListener("DOMContentLoaded", function() {
            renderMathInElement(document.body, {
                delimiters: [
                    {left: "$$", right: "$$", display: true},
                    {left: "$", right: "$", display: false},
                    {left: "\\\\(", right: "\\\\)", display: false},
                    {left: "\\\\[", right: "\\\\]", display: true}
                ],
                throwOnError: false
            });
        });
        </script>
        """
    }
    
    /// Generate footnote support script
    private static func generateFootnoteScript() -> String {
        return """
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Handle footnote references
            const footnoteRefs = document.querySelectorAll('a[href^="#fn"]');
            footnoteRefs.forEach(ref => {
                ref.addEventListener('click', function(e) {
                    e.preventDefault();
                    const target = document.querySelector(this.getAttribute('href'));
                    if (target) {
                        target.scrollIntoView({ behavior: 'smooth' });
                    }
                });
            });
            
            // Handle footnote backlinks
            const backlinks = document.querySelectorAll('a[href^="#fnref"]');
            backlinks.forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    const target = document.querySelector(this.getAttribute('href'));
                    if (target) {
                        target.scrollIntoView({ behavior: 'smooth' });
                    }
                });
            });
        });
        </script>
        """
    }
    
    /// Generate enhanced task list interaction script
    private static func generateTaskListScript() -> String {
        return """
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Add accessibility improvements for task lists
            const taskCheckboxes = document.querySelectorAll('.task-list-checkbox');
            taskCheckboxes.forEach(checkbox => {
                checkbox.setAttribute('tabindex', '0');
                checkbox.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        this.click();
                    }
                });
            });
        });
        </script>
        """
    }
    
    /// Generate JavaScript for interactive features (zoom, pan, export)
    private static func generateInteractiveScript() -> String {
        return """
        <script>
        // Add zoom and pan functionality
        document.addEventListener('DOMContentLoaded', function() {
            const diagrams = document.querySelectorAll('.mermaid-container');
            
            diagrams.forEach(function(container) {
                let scale = 1;
                let panning = false;
                let pointX = 0;
                let pointY = 0;
                let start = { x: 0, y: 0 };
                
                // Zoom with mouse wheel
                container.addEventListener('wheel', function(e) {
                    e.preventDefault();
                    const xs = (e.clientX - pointX) / scale;
                    const ys = (e.clientY - pointY) / scale;
                    const delta = e.wheelDelta ? e.wheelDelta : -e.detail;
                    scale = delta > 0 ? scale * 1.1 : scale / 1.1;
                    scale = Math.min(Math.max(0.5, scale), 3);
                    pointX = e.clientX - xs * scale;
                    pointY = e.clientY - ys * scale;
                    updateTransform(container);
                });
                
                // Pan with mouse drag
                container.addEventListener('mousedown', function(e) {
                    panning = true;
                    start = { x: e.clientX - pointX, y: e.clientY - pointY };
                    container.style.cursor = 'grabbing';
                });
                
                container.addEventListener('mouseup', function() {
                    panning = false;
                    container.style.cursor = 'grab';
                });
                
                container.addEventListener('mousemove', function(e) {
                    if (!panning) return;
                    pointX = e.clientX - start.x;
                    pointY = e.clientY - start.y;
                    updateTransform(container);
                });
                
                function updateTransform(element) {
                    const svg = element.querySelector('svg');
                    if (svg) {
                        svg.style.transform = `translate(${pointX}px, ${pointY}px) scale(${scale})`;
                    }
                }
                
                // Set initial cursor
                container.style.cursor = 'grab';
            });
            
            // Add export functionality
            window.exportDiagram = function(containerId, format) {
                const container = document.getElementById(containerId);
                if (!container) return;
                
                const svg = container.querySelector('svg');
                if (!svg) return;
                
                if (format === 'svg') {
                    const svgData = new XMLSerializer().serializeToString(svg);
                    const blob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
                    const url = URL.createObjectURL(blob);
                    downloadURL(url, 'diagram.svg');
                } else if (format === 'png') {
                    // Convert SVG to PNG using canvas
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');
                    const img = new Image();
                    
                    img.onload = function() {
                        canvas.width = img.width;
                        canvas.height = img.height;
                        ctx.drawImage(img, 0, 0);
                        canvas.toBlob(function(blob) {
                            const url = URL.createObjectURL(blob);
                            downloadURL(url, 'diagram.png');
                        });
                    };
                    
                    const svgData = new XMLSerializer().serializeToString(svg);
                    const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
                    img.src = URL.createObjectURL(svgBlob);
                }
            };
            
            function downloadURL(url, fileName) {
                const a = document.createElement('a');
                a.href = url;
                a.download = fileName;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            }
            
            // Notify Swift that diagrams are ready
            if (window.webkit && window.webkit.messageHandlers.mermaidHandler) {
                window.webkit.messageHandlers.mermaidHandler.postMessage({
                    type: 'ready',
                    diagramCount: diagrams.length
                });
            }
        });
        </script>
        <style>
        .mermaid-container {
            overflow: hidden;
            position: relative;
            width: 100%;
            height: 100%;
            user-select: none;
        }
        .mermaid-container svg {
            transform-origin: 0 0;
            transition: transform 0.1s ease-out;
        }
        </style>
        """
    }
    
    /// Generate JavaScript bridge for communication with native code
    public static func generateJavaScriptBridge() -> String {
        return """
        window.mermaidBridge = {
            // Get diagram as SVG string
            getDiagramSVG: function(containerId) {
                const container = document.getElementById(containerId);
                if (!container) return null;
                const svg = container.querySelector('svg');
                if (!svg) return null;
                return new XMLSerializer().serializeToString(svg);
            },
            
            // Update diagram content
            updateDiagram: function(containerId, newContent) {
                const container = document.getElementById(containerId);
                if (!container) return false;
                
                const pre = container.querySelector('pre.mermaid');
                if (!pre) return false;
                
                pre.textContent = newContent;
                
                if (typeof mermaid !== 'undefined') {
                    mermaid.init(undefined, pre);
                    return true;
                }
                
                return false;
            },
            
            // Get diagram metadata
            getDiagramInfo: function(containerId) {
                const container = document.getElementById(containerId);
                if (!container) return null;
                
                const svg = container.querySelector('svg');
                if (!svg) return null;
                
                return {
                    width: svg.clientWidth,
                    height: svg.clientHeight,
                    viewBox: svg.getAttribute('viewBox')
                };
            },
            
            // Apply theme
            applyTheme: function(theme) {
                if (typeof mermaid !== 'undefined') {
                    mermaid.initialize({ theme: theme });
                    // Re-render all diagrams
                    document.querySelectorAll('.mermaid').forEach(function(element) {
                        const content = element.textContent;
                        element.removeAttribute('data-processed');
                        mermaid.init(undefined, element);
                    });
                    return true;
                }
                return false;
            }
        };
        """
    }
}

#endif // canImport(SwiftUI) && canImport(WebKit)