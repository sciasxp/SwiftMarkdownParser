# SwiftMarkdownParser

[![CI](https://github.com/sciasxp/SwiftMarkdownParser/actions/workflows/ci.yml/badge.svg)](https://github.com/sciasxp/SwiftMarkdownParser/actions/workflows/ci.yml)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://developer.apple.com/macos/)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Swift-native Markdown parser with AST generation, HTML rendering, and SwiftUI support. Built for Swift 6 with async/await and zero dependencies.

## Features

- **CommonMark 0.30** compliant with **GitHub Flavored Markdown** extensions
- **HTML rendering** with syntax highlighting for 6+ programming languages
- **SwiftUI rendering** for native iOS/macOS apps (requires iOS 17.0+/macOS 14.0+)
- **AST generation** for custom processing and analysis
- **Zero dependencies** - pure Swift implementation
- **Async/await** support with Swift 6 concurrency
- **Mermaid diagram** support for both HTML and SwiftUI output
- **KaTeX math** rendering for inline and display math expressions

## Requirements

- **Swift 6.2+**
- **iOS 17.0+**
- **macOS 14.0+**

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sciasxp/SwiftMarkdownParser.git", from: "1.0.0")
]
```

## Quick Start

### HTML Rendering

```swift
import SwiftMarkdownParser

let markdown = """
# Hello World
This is **bold** and *italic* text with a [link](https://swift.org).

- [x] Completed task
- [ ] Pending task

```swift
print("Hello, World!")
```
"""

let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML(markdown)
print(html)
```

### SwiftUI Integration

```swift
import SwiftUI
import SwiftMarkdownParser

struct MarkdownView: View {
    let markdown: String
    @State private var renderedView: AnyView?

    var body: some View {
        Group {
            if let view = renderedView {
                view
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            await renderMarkdown()
        }
    }

    private func renderMarkdown() async {
        do {
            let parser = SwiftMarkdownParser()
            let ast = try parser.parse(markdown)

            let renderer = SwiftUIRenderer()
            let view = try await renderer.render(document: ast)

            await MainActor.run {
                self.renderedView = view
            }
        } catch {
            await MainActor.run {
                self.renderedView = AnyView(Text("Error: \(error.localizedDescription)"))
            }
        }
    }
}
```

### Working with the AST

```swift
import SwiftMarkdownParser

let parser = SwiftMarkdownParser()
let document = try parser.parse(markdown)

// Analyze the complete AST in stable depth-first order.
for visit in document.depthFirst() {
    switch visit.node {
    case let heading as AST.HeadingNode:
        print("Heading Level \(heading.level)")
    case let link as AST.LinkNode:
        print("Link to: \(link.url)")
    case let codeBlock as AST.CodeBlockNode:
        print("Code block (\(codeBlock.language ?? "plain"))")
    case let table as AST.GFMTableNode:
        print("Table with \(table.rows.count) rows")
    default:
        break
    }
}
```

Rewrite a document immutably with one bottom-up pass:

```swift
let rewritten = try document.rewriting { visit in
    guard let link = visit.node as? AST.LinkNode else { return .keep }
    return .replace(AST.LinkNode(
        url: "https://new.example",
        title: link.title,
        children: link.children,
        sourceLocation: link.sourceLocation
    ))
}
```

Rules may keep, remove, replace, or expand nodes. Replacements are not revisited
in the same pass.

### Syntax Highlighting

HTML renderer includes syntax highlighting for JavaScript, TypeScript, Swift, Kotlin, Python, and Bash:

```swift
let codeMarkdown = """
```swift
let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML("# Hello")
```
"""

let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML(codeMarkdown)
// Returns HTML with syntax highlighting applied
```

### Deterministic Resource Limits

```swift
let limits = SwiftMarkdownParser.ResourceLimits(
    maximumSourceLength: 2_000_000,
    maximumNestingDepth: 100,
    maximumWork: 25_000_000
)

let parser = SwiftMarkdownParser(resourceLimits: limits)
```

The Supported Dialect is fixed: CommonMark 0.30, GFM, math, and Mermaid are
always recognized. Every parser-produced node includes a precise source range.

### Mermaid Diagrams

Both HTML and SwiftUI renderers support Mermaid diagrams:

```swift
let diagramMarkdown = """
```mermaid
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Success]
    B -->|No| D[Retry]
```
"""

let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML(diagramMarkdown)
// HTML output includes embedded Mermaid diagram
```

## API Reference

### Core Classes

- `SwiftMarkdownParser` - Main parser class
- `SwiftMarkdownParser.ResourceLimits` - Deterministic source, nesting, and work limits
- `HTMLRenderer` - Renders AST to HTML with syntax highlighting
- `SwiftUIRenderer` - Renders AST to SwiftUI views (iOS 17.0+/macOS 14.0+)

### Main Methods

```swift
// Build a complete Markdown Document synchronously
func parse(_ markdown: String) throws -> AST.DocumentNode

// Parse directly to HTML
func parseToHTML(_ markdown: String, context: RenderContext = RenderContext()) async throws -> String

// Render AST with custom renderer
func render(document: AST.DocumentNode) async throws -> Output
```

## Documentation

- [HTML Renderer Guide](Docs/HTMLRenderer.md) — HTML output with syntax highlighting and theming
- [SwiftUI Renderer Guide](Docs/SwiftUIRenderer.md) — native SwiftUI rendering
- [Syntax Highlighting Guide](Docs/SyntaxHighlighting.md) — code syntax highlighting details
- [Parser Usage Guide](Docs/ParserUsage.md) — AST generation and custom processing
- [Mermaid Diagrams Guide](Docs/MermaidUsage.md) — interactive chart and diagram support
- [KaTeX Math Guide](Docs/KaTeXUsage.md) — math expression rendering
- See [`Examples/`](Examples/) directory for complete working examples
- Check [`Tests/`](Tests/) directory for comprehensive usage patterns
- Review [`CONTRIBUTING.md`](CONTRIBUTING.md) for development guidelines

## Testing

```bash
swift test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes and add tests
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.
