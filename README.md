# SwiftMarkdownParser

[![CI](https://github.com/sciasxp/SwiftMarkdownParser/actions/workflows/ci.yml/badge.svg)](https://github.com/sciasxp/SwiftMarkdownParser/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS 18.0+](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS 15.0+](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://developer.apple.com/macos/)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A modern, Swift-native Markdown parser that generates Abstract Syntax Trees (AST) with support for multiple output renderers. Built with Swift 6 concurrency and designed for performance, extensibility, and type safety.

## 🌟 Features

### Core Capabilities
- **AST-First Design**: Parse once, render to multiple formats
- **Swift 6 Compatible**: Built with modern Swift concurrency (async/await)
- **Zero Dependencies**: Pure Swift implementation
- **CommonMark Compliant**: Full CommonMark 0.30 specification support
- **GitHub Flavored Markdown**: Tables, task lists, strikethrough, autolinks
- **Performance Optimized**: Streaming tokenizer for efficient parsing
- **Type Safe**: Comprehensive Swift type system integration
- **Error Resilient**: Graceful handling of malformed markdown

### Supported Markdown Elements

#### CommonMark 0.30 Specification
- ✅ **Headings**: ATX (`# Heading`) and Setext (`Heading\n======`)
- ✅ **Paragraphs**: Multi-line text blocks
- ✅ **Emphasis**: *italic* and **bold** text
- ✅ **Links**: `[text](url)` and reference links
- ✅ **Images**: `![alt](url)` syntax
- ✅ **Code**: Inline `code` and fenced code blocks
- ✅ **Lists**: Ordered and unordered lists with nesting
- ✅ **Block Quotes**: `> quoted text`
- ✅ **Thematic Breaks**: `---` horizontal rules
- ✅ **HTML**: Inline and block HTML elements
- ✅ **Escaping**: Backslash escapes and entities

#### GitHub Flavored Markdown (GFM)
- ✅ **Tables**: Pipe-separated tables with alignment
- ✅ **Task Lists**: `- [x] completed` and `- [ ] todo`
- ✅ **Strikethrough**: `~~deleted text~~`
- ✅ **Autolinks**: Automatic URL and email detection

### Pluggable Renderer System
- **HTML Renderer**: Clean, semantic HTML output with full CommonMark + GFM support
- **SwiftUI Renderer**: Native SwiftUI views with accessibility and theming support
- **Custom CSS Classes**: Configurable styling hooks for HTML output
- **Source Location Tracking**: Debug-friendly position information
- **Extensible Architecture**: Easy to add custom renderers and output formats

### Advanced Syntax Highlighting
- **6 Programming Languages**: JavaScript, TypeScript, Swift, Kotlin, Python, Bash
- **Professional Themes**: GitHub, Xcode, VS Code Dark built-in themes (HTML renderer only)
- **25+ Token Types**: Keywords, strings, comments, operators, types, functions, and more
- **Modern Language Features**: ES6+, async/await, generics, coroutines, decorators
- **Performance Optimized**: Actor-based engine registry with LRU caching
- **Extensible Engine System**: Easy to add new languages and custom highlighting rules

## 📋 Requirements

- **iOS 18.0+** or **macOS 15.0+**
- **Swift 6.0+**
- **Xcode 16.0+**

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sciasxp/SwiftMarkdownParser.git", from: "1.0.0")
]
```

Or through Xcode:
1. **File → Add Package Dependencies**
2. Enter the repository URL
3. Select version and add to your target

## 🚀 Quick Start

### Basic HTML Rendering

```swift
import SwiftMarkdownParser

let markdown = """
# Welcome to SwiftMarkdownParser

This is **bold** and *italic* text with a [link](https://swift.org).

- [x] Parse CommonMark
- [x] Support GFM extensions  
- [x] HTML renderer ✅
- [x] SwiftUI renderer ✅
- [x] Syntax highlighting ✅

```swift
func greet(name: String) async throws -> String {
    return "Hello, \(name)!"
}
```

| Feature | Status |
|---------|--------|
| Tables | ✅ |
| Task Lists | ✅ |
| Syntax Highlighting | ✅ |
"""

// Simple HTML rendering
let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML(markdown)
print(html)
```

### SwiftUI Integration

```swift
import SwiftUI
import SwiftMarkdownParser

struct ContentView: View {
    let markdown = """
    # Hello SwiftUI!
    
    This is **native SwiftUI** rendering with:
    - Accessibility support
    - Custom theming
    - Interactive links
    """
    
    var body: some View {
        ScrollView {
            MarkdownView(markdown: markdown)
                .padding()
        }
    }
}

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
            let ast = try await parser.parseToAST(markdown)
            
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

// Parse markdown to AST first
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)

// Traverse and analyze the AST structure
func analyzeMarkdown(_ node: ASTNode) {
    switch node {
    case let heading as AST.HeadingNode:
        print("📋 Heading Level \(heading.level)")
        
    case let link as AST.LinkNode:
        print("🔗 Link to: \(link.url)")
        
    case let codeBlock as AST.CodeBlockNode:
        print("💻 Code block (\(codeBlock.language ?? "plain"))")
        
    case let table as AST.GFMTableNode:
        print("📊 Table with \(table.rows.count) rows")
        
    case let taskList as AST.GFMTaskListItemNode:
        let status = taskList.isChecked ? "✅" : "⭕"
        print("\(status) Task item")
        
    default:
        break
    }
    
    // Recursively process children
    for child in node.children {
        analyzeMarkdown(child)
    }
}

analyzeMarkdown(ast)
```

### Advanced Syntax Highlighting

SwiftMarkdownParser includes professional-grade syntax highlighting for code blocks with support for 6 programming languages and 3 built-in themes.

**Important**: Syntax highlighting is only available for the HTML renderer. The SwiftUI renderer provides basic monospace code blocks without syntax highlighting.

#### Supported Languages

- **JavaScript**: ES6+ features, async/await, template literals, JSX
- **TypeScript**: Type annotations, generics, interfaces, decorators, TSX
- **Swift**: Swift 6 syntax, property wrappers, async/await, string interpolation
- **Kotlin**: Data classes, coroutines, null safety, extension functions
- **Python**: Python 3+, async/await, triple-quoted strings, scientific notation
- **Bash**: Shell scripts, variables, control structures, built-in commands

#### Built-in Themes (HTML Renderer Only)

```swift
// Configure syntax highlighting with built-in themes
let context = RenderContext(
    styleConfiguration: StyleConfiguration(
        syntaxHighlighting: SyntaxHighlightingConfig(
            enabled: true,
            cssPrefix: "hljs-"  // default is "language-"
        )
    )
)

let renderer = HTMLRenderer(context: context)
let highlightedHTML = try await renderer.render(document: ast)
```

#### Example: Multi-language Code Blocks

```swift
let codeExamples = """
# Code Examples

## Swift
```swift
@State private var count: Int = 0

func increment() async {
    await MainActor.run {
        count += 1
    }
}
```

## JavaScript
```javascript
const fetchData = async () => {
    const response = await fetch('/api/data');
    return await response.json();
};
```

## Python
```python
async def process_data():
    data = await fetch_data()
    return [x for x in data if x > 0]
```

## Kotlin
```kotlin
data class User(val name: String, var age: Int)

suspend fun fetchUser(): User? = withContext(Dispatchers.IO) {
    // Fetch user from API
}
```
"""

let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(codeExamples)

// HTML with syntax highlighting
let htmlContext = RenderContext(
    styleConfiguration: StyleConfiguration(
        syntaxHighlighting: SyntaxHighlightingConfig(
            enabled: true,
            cssPrefix: "hljs-"
        )
    )
)

let htmlRenderer = HTMLRenderer(context: htmlContext)
let highlightedHTML = try await htmlRenderer.render(document: ast)
```

#### Custom CSS Classes for HTML Syntax Highlighting

```swift
// Custom CSS classes for HTML output
let customContext = RenderContext(
    styleConfiguration: StyleConfiguration(
        syntaxHighlighting: SyntaxHighlightingConfig(
            enabled: true,
            cssPrefix: "custom-"
        ),
        cssClasses: [
            .codeBlock: "my-code-block"
        ]
    )
)

// Then provide your own CSS rules:
// .custom-keyword { color: #0066cc; }
// .custom-string { color: #009900; }
// .custom-comment { color: #888888; }
```

#### Performance Features

The syntax highlighting system is built for performance:

- **Actor-based Registry**: Thread-safe engine management
- **LRU Caching**: Intelligent caching of highlighted code blocks
- **Lazy Loading**: Engines loaded only when needed
- **Efficient Parsing**: Single-pass tokenization with bounds checking

```swift
// Access the syntax highlighting cache
let cache = SyntaxHighlightingCache()

// Get cache statistics
let stats = await cache.getStatistics()
print("Cache hits: \(stats["totalHits"] ?? 0)")
print("Cached entries: \(stats["entryCount"] ?? 0)")

// Clear cache if needed
await cache.clearCache()
```

### Custom HTML Styling

```swift
// Configure custom styling for HTML output
let context = RenderContext(
    styleConfiguration: StyleConfiguration(
        cssClasses: [
            .heading: "custom-heading",
            .paragraph: "custom-paragraph",
            .codeBlock: "highlight-code",
            .table: "data-table",
            .emphasis: "italic-text",
            .strongEmphasis: "bold-text"
        ],
        includeSourcePositions: true
    )
)

let renderer = HTMLRenderer(context: context)
let styledHTML = try await renderer.render(document: ast)
```

### Custom SwiftUI Styling

```swift
// Configure custom styling for SwiftUI rendering
let styleConfig = SwiftUIStyleConfiguration(
    bodyFont: .system(.body, design: .serif),
    headingColor: .blue,
    linkColor: .purple,
    codeBackgroundColor: .gray.opacity(0.1)
)

let context = SwiftUIRenderContext(
    styleConfiguration: styleConfig,
    linkHandler: { url in
        // Handle link taps
        UIApplication.shared.open(url)
    }
)

let renderer = SwiftUIRenderer(context: context)
let styledView = try await renderer.render(document: ast)
```

### Advanced SwiftUI Renderer Usage

#### Accessibility and Dynamic Type Support

```swift
// SwiftUI renderer with accessibility focus
let accessibleConfig = SwiftUIStyleConfiguration(
    bodyFont: .body,  // Supports Dynamic Type automatically
    headingFonts: [
        1: .largeTitle,
        2: .title,
        3: .title2,
        4: .title3,
        5: .headline,
        6: .subheadline
    ]
)

let accessibleContext = SwiftUIRenderContext(
    styleConfiguration: accessibleConfig,
    enableAccessibility: true  // Adds VoiceOver labels and traits
)

let accessibleRenderer = SwiftUIRenderer(context: accessibleContext)
let accessibleView = try await accessibleRenderer.render(document: ast)
```

#### Interactive Links and Custom Handlers

```swift
// Handle link taps and image loading
let interactiveContext = SwiftUIRenderContext(
    linkHandler: { url in
        // Custom link handling
        if url.host == "internal.myapp.com" {
            // Handle internal navigation
            NavigationManager.shared.navigate(to: url)
        } else {
            // Open external links
            UIApplication.shared.open(url)
        }
    },
    imageHandler: { url in
        // Custom image loading with caching
        AnyView(
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
            } placeholder: {
                ProgressView()
                    .frame(height: 100)
            }
        )
    }
)

let interactiveRenderer = SwiftUIRenderer(context: interactiveContext)
```

#### Complete SwiftUI App Integration

```swift
import SwiftUI
import SwiftMarkdownParser

struct MarkdownDocumentView: View {
    let markdownContent: String
    @State private var renderedView: AnyView?
    @State private var isLoading = true
    @State private var error: Error?
    
    // Custom styling
    private let styleConfig = SwiftUIStyleConfiguration(
        bodyFont: .body,
        codeFont: .system(.body, design: .monospaced),
        headingColor: .primary,
        linkColor: .blue,
        codeBackgroundColor: Color.gray.opacity(0.1),
        blockQuoteBackgroundColor: Color.blue.opacity(0.05),
        blockQuoteBorderColor: .blue
    )
    
    var body: some View {
        ScrollView {
            Group {
                if isLoading {
                    ProgressView("Rendering markdown...")
                        .padding()
                } else if let error = error {
                    ErrorView(error: error)
                        .padding()
                } else if let view = renderedView {
                    view
                        .padding()
                } else {
                    Text("No content available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMarkdown()
        }
    }
    
    private func loadMarkdown() async {
        do {
            let parser = SwiftMarkdownParser(
                configuration: SwiftMarkdownParser.Configuration(
                    enableGFMExtensions: true,
                    trackSourceLocations: false
                )
            )
            
            let ast = try await parser.parseToAST(markdownContent)
            
            let context = SwiftUIRenderContext(
                styleConfiguration: styleConfig,
                linkHandler: { url in
                    Task { @MainActor in
                        UIApplication.shared.open(url)
                    }
                }
            )
            
            let renderer = SwiftUIRenderer(context: context)
            let view = try await renderer.render(document: ast)
            
            await MainActor.run {
                self.renderedView = view
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to render markdown")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// Usage in your app
struct ContentView: View {
    let sampleMarkdown = """
    # My Document
    
    This is a **sample** document with *various* elements:
    
    - List item 1
    - List item 2
    - [x] Completed task
    - [ ] Pending task
    
    ```swift
    let code = "Hello, World!"
    print(code)
    ```
    
    > This is a blockquote with important information.
    
    | Column 1 | Column 2 |
    |----------|----------|
    | Data A   | Data B   |
    """
    
    var body: some View {
        NavigationView {
            MarkdownDocumentView(markdownContent: sampleMarkdown)
                .navigationTitle("Markdown Example")
        }
    }
}
```

### GFM Table Example

```swift
let tableMarkdown = """
| Feature | Status | Notes |
|---------|--------|-------|
| Tables | ✅ | Full support |
| Task Lists | ✅ | Checkboxes work |
| Strikethrough | ✅ | ~~deprecated~~ |
"""

let ast = try await parser.parseToAST(tableMarkdown)
let html = try await parser.parseToHTML(tableMarkdown)

// Output: Clean HTML table with proper structure
```

### Advanced HTML Renderer Usage

#### Security and URL Handling

```swift
// Configure secure HTML rendering
let secureContext = RenderContext(
    baseURL: URL(string: "https://mysite.com"),
    sanitizeHTML: true,  // Escapes raw HTML for security
    styleConfiguration: StyleConfiguration()
)

let renderer = HTMLRenderer(context: secureContext)
let safeHTML = try await renderer.render(document: ast)
```

#### CSS Classes and Custom Styling

```swift
// Add CSS classes for styling
let styledContext = RenderContext(
    styleConfiguration: StyleConfiguration(
        cssClasses: [
            .heading: "article-heading",
            .paragraph: "article-text",
            .codeBlock: "code-highlight",
            .table: "data-table striped",
            .blockQuote: "quote-block",
            .emphasis: "italic",
            .strongEmphasis: "bold",
            .link: "external-link"
        ],
        includeSourcePositions: true,  // Adds data-source-line attributes
        syntaxHighlighting: SyntaxHighlightingConfig(
            enabled: true,
            theme: .github,
            cssPrefix: "hljs-"
        )
    )
)

let styledHTML = try await HTMLRenderer(context: styledContext).render(document: ast)
```

#### Complete Example with Error Handling

```swift
import SwiftMarkdownParser

func renderMarkdownToHTML(_ markdown: String) async throws -> String {
    do {
        // Create parser with GFM extensions
        let config = SwiftMarkdownParser.Configuration(
            enableGFMExtensions: true,
            strictMode: false,
            trackSourceLocations: true
        )
        let parser = SwiftMarkdownParser(configuration: config)
        
        // Parse to AST
        let ast = try await parser.parseToAST(markdown)
        
        // Configure HTML rendering
        let context = RenderContext(
            baseURL: URL(string: "https://example.com"),
            sanitizeHTML: true,
            styleConfiguration: StyleConfiguration(
                cssClasses: [
                    .heading: "heading",
                    .codeBlock: "code-block"
                ],
                includeSourcePositions: true
            )
        )
        
        // Render to HTML
        let html = try await HTMLRenderer(context: context).render(document: ast)
        return html
        
    } catch MarkdownParserError.invalidInput(let message) {
        throw NSError(domain: "MarkdownError", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Invalid markdown: \(message)"
        ])
    } catch RendererError.unsupportedNodeType(let nodeType) {
        throw NSError(domain: "RenderError", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Unsupported element: \(nodeType)"
        ])
    }
}

// Usage
let html = try await renderMarkdownToHTML(markdownContent)
```

## 🏗️ Architecture

### AST-Focused Design

The parser uses a three-stage pipeline:

1. **Tokenization**: Break markdown into structured tokens
2. **Block Parsing**: Build block-level AST structure  
3. **Inline Processing**: Parse inline elements and GFM extensions

```swift
// The same AST can be rendered to multiple formats
let ast = try await parser.parseToAST(markdown)

// HTML output
let htmlRenderer = HTMLRenderer()
let html = try await htmlRenderer.render(document: ast)

// SwiftUI output
let swiftUIRenderer = SwiftUIRenderer()
let views = try await swiftUIRenderer.render(document: ast)

// Both renderers work from the same AST!
```

### Performance Characteristics

- **Streaming Parser**: Processes large documents efficiently
- **Memory Efficient**: Minimal allocations during parsing
- **Concurrent Safe**: Thread-safe parsing with Swift 6 concurrency
- **Fast Tokenization**: Optimized character-by-character scanning

## ✅ Advantages

### 🚀 **Performance & Efficiency**
- **Native Swift**: No C/C++ bridge overhead
- **Streaming Architecture**: Handles large documents without memory spikes
- **Optimized Tokenizer**: Single-pass character scanning
- **Concurrent Processing**: Built for Swift 6 async/await

### 🎯 **Developer Experience**
- **Type Safety**: Full Swift type system integration
- **Rich AST**: Comprehensive node types with metadata
- **Error Handling**: Detailed error messages with source locations
- **Extensible**: Easy to add custom renderers and extensions

### 🔧 **Modern Swift Features**
- **Swift 6 Concurrency**: Native async/await support
- **Sendable Compliance**: Thread-safe by design
- **Zero Dependencies**: No external libraries required
- **Package Manager**: Easy SPM integration

### 📱 **Apple Platform Integration**
- **iOS/macOS Native**: Designed for Apple platforms
- **SwiftUI Ready**: AST structure perfect for SwiftUI rendering
- **Memory Efficient**: Optimized for mobile constraints
- **Future Proof**: Ready for upcoming Swift features

## ⚠️ Disadvantages

### 🎯 **Platform Limitations**
- **Apple Platforms Only**: Currently iOS 17+/macOS 14+ for SwiftUI (iOS 13+/macOS 10.15+ for HTML only)
- **Swift 6 Requirement**: Needs latest Swift version
- **Limited Ecosystem**: Newer project with smaller community

### 🔧 **Feature Gaps**
- **Math Extensions**: No LaTeX/MathJax support yet
- **Plugins**: No plugin system for custom extensions
- **Additional Languages**: Currently supports 6 languages (more coming soon)
- **Performance**: May be slower than C-based parsers for massive documents

### 📚 **Maturity Considerations**
- **New Project**: Less battle-tested than established parsers
- **Documentation**: Still growing documentation and examples
- **Edge Cases**: May have undiscovered parsing edge cases

## 🔄 Comparison with Alternatives

| Feature | SwiftMarkdownParser | swift-markdown | Down | Other Parsers |
|---------|-------------------|----------------|------|---------------|
| Swift Native | ✅ | ✅ | ✅ | ❌ |
| AST-First | ✅ | ✅ | ❌ | ❌ |
| GFM Support | ✅ | ✅ | ✅ | ✅ |
| Swift 6 Ready | ✅ | ❌ | ❌ | ❌ |
| Zero Dependencies | ✅ | ❌ | ❌ | ❌ |
| HTML Renderer | ✅ | ❌ | ✅ | ✅ |
| SwiftUI Renderer | ✅ | ❌ | ❌ | ❌ |
| Multiple Renderers | ✅ | ❌ | ❌ | ❌ |
| Syntax Highlighting | ✅ | ❌ | ❌ | ⚠️ |
| Built-in Themes | ✅ | ❌ | ❌ | ❌ |
| iOS 17+ Only | ⚠️ | ❌ | ❌ | ❌ |

## 🛠️ Advanced Usage

### Custom Parser Configuration

```swift
let config = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true,       // GitHub Flavored Markdown extensions
    strictMode: false,               // Relaxed parsing rules  
    maxNestingDepth: 100,           // Maximum nesting depth for recursive elements
    trackSourceLocations: true,     // Include source position information
    maxParsingTime: 30.0            // Maximum parsing time in seconds (0 = no limit)
)

let parser = SwiftMarkdownParser(configuration: config)
```

#### Configuration Options

- **enableGFMExtensions**: Enable GitHub Flavored Markdown features (tables, task lists, strikethrough, autolinks)
- **strictMode**: Enable strict CommonMark compliance mode vs. relaxed parsing
- **maxNestingDepth**: Maximum nesting depth for recursive elements to prevent stack overflow
- **trackSourceLocations**: Include source position information in AST nodes for debugging
- **maxParsingTime**: Maximum parsing time in seconds before timeout (default: 30.0, set to 0 for no limit)

#### Performance and Safety Features

SwiftMarkdownParser includes intelligent protection mechanisms:

- **Time-based protection**: Configurable timeout prevents runaway parsing on malicious or extremely complex documents
- **Infinite loop detection**: Advanced position tracking detects and prevents parser from getting stuck
- **Memory safety**: Nesting depth limits prevent stack overflow on deeply nested structures
- **No artificial limits**: Unlike older parsers, there are no arbitrary block count limits - documents can be any reasonable size

For large documents (like technical documentation), you may want to increase the timeout:

```swift
// Configuration for large documents
let largeDocConfig = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true,
    maxParsingTime: 60.0  // 60 seconds for complex documents
)
```

### Error Handling

```swift
do {
    let ast = try await parser.parseToAST(markdown)
    let html = try await parser.parseToHTML(markdown)
} catch MarkdownParsingError.invalidInput(let message) {
    print("Invalid input: \(message)")
} catch MarkdownParsingError.nestingTooDeep(let depth) {
    print("Nesting too deep: \(depth)")
} catch {
    print("Parsing failed: \(error)")
}
```

### Custom Renderer Implementation

```swift
// Example: Plain text renderer
struct PlainTextRenderer: MarkdownRenderer {
    typealias Output = String
    
    func render(document: AST.DocumentNode) async throws -> String {
        var result = ""
        for child in document.children {
            result += try await render(node: child)
        }
        return result
    }
    
    func render(node: ASTNode) async throws -> String {
        switch node {
        case let text as AST.TextNode:
            return text.content
        case let heading as AST.HeadingNode:
            let content = try await renderChildren(heading.children)
            return "\n" + String(repeating: "#", count: heading.level) + " " + content + "\n"
        case let paragraph as AST.ParagraphNode:
            let content = try await renderChildren(paragraph.children)
            return content + "\n\n"
        case let emphasis as AST.EmphasisNode:
            let content = try await renderChildren(emphasis.children)
            return "*" + content + "*"
        case let strong as AST.StrongEmphasisNode:
            let content = try await renderChildren(strong.children)
            return "**" + content + "**"
        default:
            // Render children for unknown nodes
            return try await renderChildren(node.children)
        }
    }
    
    private func renderChildren(_ children: [ASTNode]) async throws -> String {
        var result = ""
        for child in children {
            result += try await render(node: child)
        }
        return result
    }
}

// Usage
let plainTextRenderer = PlainTextRenderer()
let plainText = try await plainTextRenderer.render(document: ast)
```

## 📚 Documentation

For comprehensive guides and examples, check out our detailed documentation:

### Core Documentation
- **[Parser Usage Guide](Docs/ParserUsage.md)** - Complete guide to parsing markdown into AST, configuration options, AST traversal, and advanced parsing techniques
- **[HTML Renderer Guide](Docs/HTMLRenderer.md)** - Comprehensive HTML rendering documentation with styling, security, and customization options
- **[SwiftUI Renderer Guide](Docs/SwiftUIRenderer.md)** - Native SwiftUI rendering with theming, accessibility, and platform integration
- **[Syntax Highlighting Guide](Docs/SyntaxHighlighting.md)** - Professional code block highlighting with 6 languages, themes, and performance optimization

### Quick Links
- [Getting Started with AST Parsing](Docs/ParserUsage.md#quick-start)
- [HTML Rendering Examples](Docs/HTMLRenderer.md#basic-usage)
- [SwiftUI Integration Examples](Docs/SwiftUIRenderer.md#basic-usage)
- [Syntax Highlighting Setup](Docs/SyntaxHighlighting.md#quick-start)
- [Built-in Themes](Docs/SyntaxHighlighting.md#built-in-themes)
- [Custom Theme Creation](Docs/SyntaxHighlighting.md#custom-themes)
- [Error Handling Best Practices](Docs/ParserUsage.md#error-handling)
- [Performance Optimization Tips](Docs/HTMLRenderer.md#performance-tips)
- [Accessibility Features](Docs/SwiftUIRenderer.md#accessibility)

## 🧪 Testing

The project includes comprehensive tests covering:

- **Parser Functionality**: All CommonMark and GFM features
- **Edge Cases**: Malformed input and error conditions  
- **Performance**: Large document handling
- **Renderer Output**: HTML generation accuracy

```bash
# Run tests
swift test

# Run specific test
swift test --filter SwiftMarkdownParserTests
```

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing bugs, adding features, improving documentation, or helping with tests, your contributions make SwiftMarkdownParser better for everyone.

### Quick Start for Contributors

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/SwiftMarkdownParser.git
   cd SwiftMarkdownParser
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes** and add tests
5. **Verify everything works**:
   ```bash
   swift test
   ```
6. **Commit and push**:
   ```bash
   git commit -m "Add your feature description"
   git push origin feature/your-feature-name
   ```
7. **Create a Pull Request** on GitHub

### Areas We Need Help With

- 🚀 **Performance optimizations**: Tokenizer and parser improvements
- 📱 **SwiftUI renderer**: Native SwiftUI output format  
- 📊 **GFM extensions**: Math support, footnotes, definition lists
- 📚 **Documentation**: API docs, tutorials, and examples
- 🧪 **Test coverage**: Edge cases and performance tests
- 🎨 **Syntax highlighting**: Additional programming languages (Go, Rust, C++, etc.)
- 🎨 **Themes**: More built-in color themes and theme customization

### Good First Issues

Perfect for new contributors:
- 📝 Documentation improvements and typo fixes
- ✅ Adding missing test cases
- 🧹 Code cleanup and refactoring
- 💡 Example projects demonstrating usage

For detailed contribution guidelines, code style, testing requirements, and the review process, please see our **[CONTRIBUTING.md](CONTRIBUTING.md)** guide.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [CommonMark Specification](https://spec.commonmark.org/) for the parsing standards
- [GitHub Flavored Markdown](https://github.github.com/gfm/) for the GFM extensions
- Swift community for the excellent async/await foundation

---

**Made with ❤️ for the Swift community** 