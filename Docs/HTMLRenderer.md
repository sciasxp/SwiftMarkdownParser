# HTML Renderer Documentation

Complete guide to using the SwiftMarkdownParser HTML renderer for converting markdown to clean, semantic HTML.

## Table of Contents

- [Quick Start](#quick-start)
- [Basic Usage](#basic-usage)
- [Configuration](#configuration)
- [CSS Classes and Styling](#css-classes-and-styling)
- [Security Features](#security-features)
- [Syntax Highlighting](#syntax-highlighting)
- [Error Handling](#error-handling)
- [Advanced Examples](#advanced-examples)
- [Performance Tips](#performance-tips)
- [API Reference](#api-reference)

## Quick Start

```swift
import SwiftMarkdownParser

// Simple HTML rendering
let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML("# Hello **World**!")
print(html) // <h1>Hello <strong>World</strong>!</h1>
```

## Basic Usage

### Creating an HTML Renderer

```swift
// Using default configuration
let renderer = HTMLRenderer()

// Using custom context
let context = RenderContext(
    baseURL: URL(string: "https://example.com"),
    sanitizeHTML: true,
    styleConfiguration: StyleConfiguration()
)
let renderer = HTMLRenderer(context: context)
```

### Rendering Documents

```swift
// Method 1: Using parser convenience method
let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML(markdown)

// Method 2: Using renderer directly
let ast = try await parser.parseToAST(markdown)
let renderer = HTMLRenderer()
let html = try await renderer.render(document: ast)

// Method 3: Rendering individual nodes
let textNode = AST.TextNode(content: "Hello World")
let html = try await renderer.render(node: textNode)
```

## Configuration

### Parser Configuration

```swift
let config = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true,      // GitHub Flavored Markdown
    strictMode: false,              // Relaxed parsing rules
    maxNestingDepth: 100,          // Prevent infinite recursion
    trackSourceLocations: true     // Include position information
)

let parser = SwiftMarkdownParser(configuration: config)
```

### Render Context Configuration

```swift
let context = RenderContext(
    baseURL: URL(string: "https://example.com"),
    sanitizeHTML: true,
    styleConfiguration: StyleConfiguration(),
    linkReferences: [:],
    depth: 0
)
```

#### Parameters

- **baseURL**: Resolves relative URLs in links and images
- **sanitizeHTML**: Escapes raw HTML for security (default: true)
- **styleConfiguration**: CSS classes and styling options
- **linkReferences**: Link reference definitions from document
- **depth**: Current rendering depth (used internally)

## CSS Classes and Styling

### Adding CSS Classes

```swift
let styleConfig = StyleConfiguration(
    cssClasses: [
        .heading: "article-heading",
        .paragraph: "article-text", 
        .codeBlock: "code-highlight",
        .table: "data-table striped",
        .blockQuote: "quote-block",
        .emphasis: "italic",
        .strongEmphasis: "bold",
        .link: "external-link",
        .image: "responsive-image",
        .list: "custom-list",
        .listItem: "list-item",
        .thematicBreak: "divider"
    ],
    includeSourcePositions: true
)
```

### Generated HTML Structure

```html
<!-- Heading with CSS class -->
<h1 class="article-heading">My Title</h1>

<!-- Paragraph with source position -->
<p class="article-text" data-source-line="5" data-source-column="1">
    Text with <strong class="bold">emphasis</strong>
</p>

<!-- Code block with syntax highlighting -->
<pre class="code-highlight">
    <code class="hljs-swift">let x = 5</code>
</pre>
```

### Custom Attributes

```swift
let styleConfig = StyleConfiguration(
    customAttributes: [
        .heading: ["role": "banner"],
        .table: ["role": "grid", "tabindex": "0"],
        .link: ["target": "_blank", "rel": "noopener"]
    ]
)
```

## Security Features

### HTML Sanitization

```swift
// Enable HTML sanitization (default)
let context = RenderContext(sanitizeHTML: true)

// Raw HTML is escaped for security
let markdown = "Click <script>alert('xss')</script> here"
let html = try await parser.parseToHTML(markdown, context: context)
// Output: "Click &lt;script&gt;alert('xss')&lt;/script&gt; here"
```

### URL Validation

```swift
// URLs are automatically validated and normalized
let markdown = "[Click here](javascript:alert('xss'))"
let html = try await parser.parseToHTML(markdown)
// Dangerous URLs are stripped, only safe URLs preserved
```

### Base URL Resolution

```swift
let context = RenderContext(
    baseURL: URL(string: "https://example.com/docs/")
)

// Relative URLs are resolved against base URL
let markdown = "[Guide](../guide.html)"
// Output: <a href="https://example.com/guide.html">Guide</a>
```

## Syntax Highlighting

### Configuration

```swift
let syntaxConfig = SyntaxHighlightingConfig(
    enabled: true,
    cssPrefix: "hljs-",                    // CSS class prefix
    supportedLanguages: [
        "swift", "javascript", "python", 
        "html", "css", "json", "yaml"
    ]
)

let styleConfig = StyleConfiguration(
    syntaxHighlighting: syntaxConfig
)
```

### Generated Output

```html
<!-- Code block with language -->
<pre class="code-block">
    <code class="hljs-swift">
let greeting = "Hello, World!"
print(greeting)
    </code>
</pre>

<!-- Inline code -->
<code class="code-span">Array&lt;String&gt;</code>
```

### Integration with Highlight.js

```html
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/default.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
</head>
<body>
    <!-- Your generated HTML here -->
</body>
</html>
```

## Error Handling

### Common Errors

```swift
do {
    let html = try await parser.parseToHTML(markdown)
} catch MarkdownParserError.invalidInput(let message) {
    print("Invalid markdown: \(message)")
} catch MarkdownParserError.malformedMarkdown(let message, let location) {
    if let location = location {
        print("Error at line \(location.line): \(message)")
    }
} catch RendererError.unsupportedNodeType(let nodeType) {
    print("Unsupported element: \(nodeType)")
} catch RendererError.invalidURL(let url) {
    print("Invalid URL: \(url)")
} catch {
    print("Rendering failed: \(error)")
}
```

### Error Recovery

```swift
func safeRenderHTML(_ markdown: String) async -> String {
    do {
        return try await parser.parseToHTML(markdown)
    } catch {
        // Fallback to escaped text
        return RendererUtils.escapeHTML(markdown)
    }
}
```

## Advanced Examples

### Complete Blog Post Renderer

```swift
import SwiftMarkdownParser

struct BlogPostRenderer {
    private let parser: SwiftMarkdownParser
    private let context: RenderContext
    
    init(baseURL: URL) {
        self.parser = SwiftMarkdownParser(
            configuration: SwiftMarkdownParser.Configuration(
                enableGFMExtensions: true,
                trackSourceLocations: true
            )
        )
        
        self.context = RenderContext(
            baseURL: baseURL,
            sanitizeHTML: true,
            styleConfiguration: StyleConfiguration(
                cssClasses: [
                    .heading: "post-heading",
                    .paragraph: "post-text",
                    .codeBlock: "code-block",
                    .table: "post-table",
                    .blockQuote: "post-quote",
                    .image: "post-image"
                ],
                includeSourcePositions: true,
                syntaxHighlighting: SyntaxHighlightingConfig(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
    }
    
    func renderPost(_ markdown: String) async throws -> String {
        let html = try await parser.parseToHTML(markdown, context: context)
        return wrapInTemplate(html)
    }
    
    private func wrapInTemplate(_ content: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Blog Post</title>
            <link rel="stylesheet" href="/styles/blog.css">
            <link rel="stylesheet" href="/styles/highlight.css">
        </head>
        <body>
            <article class="blog-post">
                \(content)
            </article>
            <script src="/js/highlight.min.js"></script>
            <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }
}

// Usage
let renderer = BlogPostRenderer(baseURL: URL(string: "https://myblog.com")!)
let html = try await renderer.renderPost(markdownContent)
```

### Custom Node Processing

```swift
extension HTMLRenderer {
    func renderWithCustomHeadings(_ document: AST.DocumentNode) async throws -> String {
        var html = ""
        
        for child in document.children {
            if let heading = child as? AST.HeadingNode {
                // Custom heading with anchor links
                let id = generateHeadingId(heading)
                let content = try await renderChildren(heading.children)
                html += """
                <h\(heading.level) id="\(id)" class="heading-with-anchor">
                    <a href="#\(id)" class="anchor-link">#</a>
                    \(content)
                </h\(heading.level)>
                """
            } else {
                html += try await render(node: child)
            }
        }
        
        return html
    }
    
    private func generateHeadingId(_ heading: AST.HeadingNode) -> String {
        // Extract text content and create URL-safe ID
        let text = extractTextContent(heading.children)
        return text.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
    }
    
    private func extractTextContent(_ nodes: [ASTNode]) -> String {
        return nodes.compactMap { node in
            if let textNode = node as? AST.TextNode {
                return textNode.content
            }
            return extractTextContent(node.children)
        }.joined()
    }
    
    private func renderChildren(_ children: [ASTNode]) async throws -> String {
        var result = ""
        for child in children {
            result += try await render(node: child)
        }
        return result
    }
}
```

## Performance Tips

### Batch Processing

```swift
// Process multiple documents efficiently
func renderMultipleDocuments(_ markdowns: [String]) async throws -> [String] {
    let parser = SwiftMarkdownParser()
    let renderer = HTMLRenderer()
    
    return try await withThrowingTaskGroup(of: String.self) { group in
        for markdown in markdowns {
            group.addTask {
                let ast = try await parser.parseToAST(markdown)
                return try await renderer.render(document: ast)
            }
        }
        
        var results: [String] = []
        for try await html in group {
            results.append(html)
        }
        return results
    }
}
```

### Memory Management

```swift
// For large documents, process in chunks
func renderLargeDocument(_ markdown: String) async throws -> String {
    let parser = SwiftMarkdownParser()
    
    // Split into smaller sections if needed
    let sections = splitMarkdownSections(markdown)
    var htmlSections: [String] = []
    
    for section in sections {
        let html = try await parser.parseToHTML(section)
        htmlSections.append(html)
        
        // Allow memory cleanup between sections
        try await Task.sleep(nanoseconds: 1000)
    }
    
    return htmlSections.joined(separator: "\n")
}
```

## API Reference

### HTMLRenderer

```swift
public struct HTMLRenderer: MarkdownRenderer {
    public typealias Output = String
    
    public init(context: RenderContext = RenderContext(), 
                configuration: SwiftMarkdownParser.Configuration = SwiftMarkdownParser.Configuration())
    
    public func render(document: AST.DocumentNode) async throws -> String
    public func render(node: ASTNode) async throws -> String
}
```

### RenderContext

```swift
public struct RenderContext: Sendable {
    public let baseURL: URL?
    public let sanitizeHTML: Bool
    public let styleConfiguration: StyleConfiguration
    public let linkReferences: [String: LinkReference]
    public let depth: Int
    
    public init(baseURL: URL? = nil, 
                sanitizeHTML: Bool = true, 
                styleConfiguration: StyleConfiguration = .default, 
                linkReferences: [String: LinkReference] = [:], 
                depth: Int = 0)
    
    public func incrementingDepth() -> RenderContext
}
```

### StyleConfiguration

```swift
public struct StyleConfiguration: Sendable {
    public let cssClasses: [ASTNodeType: String]
    public let customAttributes: [ASTNodeType: [String: String]]
    public let includeSourcePositions: Bool
    public let syntaxHighlighting: SyntaxHighlightingConfig
    
    public init(cssClasses: [ASTNodeType: String] = [:], 
                customAttributes: [ASTNodeType: [String: String]] = [:], 
                includeSourcePositions: Bool = false, 
                syntaxHighlighting: SyntaxHighlightingConfig = .default)
    
    public static let `default`: StyleConfiguration
}
```

### Supported Node Types

All CommonMark 0.30 and GitHub Flavored Markdown elements are supported:

- **Text Elements**: TextNode, EmphasisNode, StrongEmphasisNode
- **Block Elements**: ParagraphNode, HeadingNode, BlockQuoteNode
- **Lists**: ListNode, ListItemNode
- **Code**: CodeSpanNode, CodeBlockNode  
- **Links & Images**: LinkNode, ImageNode, AutolinkNode
- **Structure**: ThematicBreakNode, LineBreakNode, SoftBreakNode
- **HTML**: HTMLBlockNode, HTMLInlineNode
- **GFM Extensions**: GFMTableNode, GFMTableRowNode, GFMTableCellNode, GFMTaskListItemNode, StrikethroughNode

---

**Next Steps**: Check out the [SwiftUI Renderer Documentation](SwiftUIRenderer.md) for native iOS/macOS rendering. 