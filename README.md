# Swift Markdown Parser

A lightweight, Swift-native library for parsing Markdown documents into Abstract Syntax Trees (AST) with pluggable renderers for multiple output formats.

## Features

- **AST-First Design**: Parse once, render to multiple formats
- **Swift 6 Compatible**: Built with the latest Swift language features and async/await
- **iOS 18+ & macOS 15+**: Supports the latest Apple platforms  
- **Zero Dependencies**: Pure Swift implementation with no external dependencies
- **CommonMark Compliant**: Full CommonMark 0.30 specification support
- **GitHub Flavored Markdown**: Tables, task lists, strikethrough, autolinks
- **Pluggable Renderers**: HTML, SwiftUI, and custom output formats
- **Performance Optimized**: Streaming parser for large documents
- **Error Resilient**: Graceful handling of malformed markdown

## Architecture

### AST-Focused Design

The parser generates a comprehensive Abstract Syntax Tree (AST) that represents the markdown structure in a renderer-agnostic format. This allows:

- **Multiple Output Formats**: Same AST can be rendered to HTML, SwiftUI, PDF, etc.
- **Custom Renderers**: Easy to implement new output formats
- **Rich Structure**: Preserves all markdown semantics and metadata
- **Future Proof**: Add new renderers without changing the parser

### Pluggable Renderer System

```swift
// Parse markdown to AST
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)

// Render to HTML
let htmlRenderer = HTMLRenderer()
let html = try await htmlRenderer.render(document: ast)

// Render to SwiftUI (future)
let swiftUIRenderer = SwiftUIRenderer()
let views = try await swiftUIRenderer.render(document: ast)
```

## Requirements

- iOS 18.0+
- macOS 15.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftMarkdownParser.git", from: "1.0.0")
]
```

Or add it through Xcode:

1. Go to File → Add Package Dependencies
2. Enter the repository URL
3. Select the version and add to your target

## Quick Start

### Basic Usage

```swift
import SwiftMarkdownParser

let markdown = """
# Hello World

This is **bold** and *italic* text with a [link](https://swift.org).

```swift
let code = "Hello, Swift!"
```

> A thoughtful quote
"""

// Parse to AST
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)

// Render to HTML
let html = try await parser.parseToHTML(markdown)
print(html)
```

### Custom Renderer Configuration

```swift
// Configure custom styling
let context = RenderContext(
    styleConfiguration: StyleConfiguration(
        cssClasses: [
            .heading: "my-heading",
            .paragraph: "my-paragraph",
            .codeBlock: "my-code"
        ],
        includeSourcePositions: true,
        syntaxHighlighting: SyntaxHighlightingConfig(
            enabled: true,
            cssPrefix: "hljs-"
        )
    )
)

let renderer = HTMLRenderer(context: context)
let styledHTML = try await renderer.render(document: ast)
```

### Working with the AST

```swift
// Traverse the AST
func processAST(_ node: ASTNode) {
    switch node {
    case let heading as HeadingNode:
        print("Found heading level \(heading.level)")
        
    case let link as LinkNode:
        print("Found link to: \(link.url)")
        
    case let codeBlock as CodeBlockNode:
        print("Found code in language: \(codeBlock.language ?? "none")")
        
    default:
        break
    }
    
    // Process children
    for child in node.children {
        processAST(child)
    }
}

processAST(ast)
```

## Supported Markdown Features

### CommonMark 0.30 Specification

- **Block Elements**: 
  - Headers (ATX `#` and Setext `===`/`---`)
  - Paragraphs with soft/hard line breaks
  - Block quotes (`>`)
  - Lists (ordered and unordered)
  - Code blocks (indented and fenced)
  - Thematic breaks (`---`, `***`, `___`)
  - HTML blocks

- **Inline Elements**:
  - Emphasis (`*italic*`, `_italic_`)
  - Strong emphasis (`**bold**`, `__bold__`)
  - Links (`[text](url)`, reference links)
  - Images (`![alt](url)`, reference images)
  - Code spans (`` `code` ``)
  - Line breaks and soft breaks
  - HTML inline elements
  - Entity references (`&amp;`, `&#39;`)

### GitHub Flavored Markdown Extensions

- **Tables**: Full table support with column alignment
  ```markdown
  | Left | Center | Right |
  |:-----|:------:|------:|
  | L1   | C1     | R1    |
  ```

- **Task Lists**: Interactive checkboxes
  ```markdown
  - [x] Completed task
  - [ ] Pending task
  ```

- **Strikethrough**: `~~deleted text~~`

- **Autolinks**: Automatic URL and email detection
  - `https://example.com` → clickable link
  - `user@example.com` → mailto link

## AST Node Types

The parser generates a rich AST with the following node types:

### Block Nodes
- `DocumentNode` - Root container
- `ParagraphNode` - Text paragraphs  
- `HeadingNode` - Headers (levels 1-6)
- `BlockQuoteNode` - Block quotes
- `CodeBlockNode` - Code blocks
- `ListNode` - Ordered/unordered lists
- `ListItemNode` - List items
- `TableNode` - Tables (GFM)
- `ThematicBreakNode` - Horizontal rules

### Inline Nodes
- `TextNode` - Plain text
- `EmphasisNode` - Italic text
- `StrongEmphasisNode` - Bold text
- `LinkNode` - Hyperlinks
- `ImageNode` - Images
- `CodeSpanNode` - Inline code
- `StrikethroughNode` - Deleted text (GFM)
- `LineBreakNode` - Line breaks

## Renderer Development

### Creating Custom Renderers

Implement the `MarkdownRenderer` protocol:

```swift
struct MyCustomRenderer: MarkdownRenderer {
    typealias Output = String
    
    func render(document: DocumentNode) async throws -> String {
        // Render the complete document
        var output = ""
        for child in document.children {
            output += try await render(node: child)
        }
        return output
    }
    
    func render(node: ASTNode) async throws -> String {
        switch node {
        case let heading as HeadingNode:
            return "HEADING[\(heading.level)]: \(renderChildren(heading.children))"
            
        case let text as TextNode:
            return text.content
            
        // Handle other node types...
        default:
            throw RendererError.unsupportedNodeType(node.nodeType)
        }
    }
}
```

### Future SwiftUI Renderer

```swift
@available(iOS 18.0, macOS 15.0, *)
struct SwiftUIRenderer: MarkdownRenderer {
    typealias Output = AnyView
    
    func render(node: ASTNode) async throws -> AnyView {
        switch node {
        case let heading as HeadingNode:
            return AnyView(
                Text(heading.textContent)
                    .font(.title)
                    .bold()
            )
            
        case let paragraph as ParagraphNode:
            return AnyView(
                Text(paragraph.textContent)
                    .font(.body)
            )
            
        // More SwiftUI implementations...
        }
    }
}
```

## Performance

- **Streaming Parser**: Handles large documents efficiently
- **Memory Optimized**: Minimal memory footprint
- **Lazy Evaluation**: Process only what's needed
- **Async/Await**: Non-blocking parsing for large files

## Error Handling

The parser provides comprehensive error handling:

```swift
do {
    let ast = try await parser.parseToAST(markdown)
} catch MarkdownParserError.malformedMarkdown(let message, let location) {
    print("Parse error at line \(location?.line ?? 0): \(message)")
} catch MarkdownParserError.nestingTooDeep(let depth) {
    print("Nesting too deep: \(depth) levels")
} catch {
    print("Unexpected error: \(error)")
}
```

## Contributing

Contributions are welcome! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Roadmap

- [x] Core CommonMark 0.30 compliance
- [x] AST-first architecture
- [x] HTML renderer
- [x] GitHub Flavored Markdown extensions
- [ ] SwiftUI renderer
- [ ] PDF renderer
- [ ] Syntax highlighting
- [ ] Custom extension API
- [ ] Performance optimizations
- [ ] Comprehensive test suite

## Support

For questions, issues, or contributions, please visit the [GitHub repository](https://github.com/yourusername/SwiftMarkdownParser). 