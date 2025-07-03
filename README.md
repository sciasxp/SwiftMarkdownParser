# SwiftMarkdownParser

[![CI](https://github.com/sciasxp/SwiftMarkdownParser/actions/workflows/ci.yml/badge.svg)](https://github.com/sciasxp/SwiftMarkdownParser/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS 18.0+](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS 15.0+](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://developer.apple.com/macos/)
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
- **HTML Renderer**: Clean, semantic HTML output
- **Custom CSS Classes**: Configurable styling hooks
- **Source Location Tracking**: Debug-friendly position information
- **Future Renderers**: SwiftUI, PDF, and custom formats

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

### Basic Usage

```swift
import SwiftMarkdownParser

let markdown = """
# Welcome to SwiftMarkdownParser

This is **bold** and *italic* text with a [link](https://swift.org).

## Code Example

```swift
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)
```

- [x] Parse CommonMark
- [x] Support GFM extensions  
- [ ] Add SwiftUI renderer

```swift
// Parse to AST
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)

// Render to HTML
let html = try await parser.parseToHTML(markdown)
print(html)
```

### Working with the AST

```swift
// Traverse and analyze the AST
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

### Custom HTML Rendering

```swift
// Configure custom styling
let context = RenderContext(
    styleConfiguration: StyleConfiguration(
        cssClasses: [
            .heading: "custom-heading",
            .paragraph: "custom-paragraph",
            .codeBlock: "highlight-code",
            .table: "data-table"
        ],
        includeSourcePositions: true
    )
)

let renderer = HTMLRenderer(context: context)
let styledHTML = try await renderer.render(document: ast)
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

// Future: SwiftUI output
let swiftUIRenderer = SwiftUIRenderer()
let views = try await swiftUIRenderer.render(document: ast)
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
- **Apple Platforms Only**: Currently iOS 18+/macOS 15+ (could be lowered)
- **Swift 6 Requirement**: Needs latest Swift version
- **Limited Ecosystem**: Newer project with smaller community

### 🔧 **Feature Gaps**
- **Math Extensions**: No LaTeX/MathJax support yet
- **Plugins**: No plugin system for custom extensions
- **Syntax Highlighting**: Basic code block support only
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
| Multiple Renderers | ✅ | ❌ | ❌ | ❌ |
| iOS 18+ Only | ⚠️ | ❌ | ❌ | ❌ |

## 🛠️ Advanced Usage

### Custom Parser Configuration

```swift
let config = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true,
    strictMode: false,
    maxNestingDepth: 100,
    trackSourceLocations: true
)

let parser = SwiftMarkdownParser(configuration: config)
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
            return "# " + (try await renderChildren(heading.children))
        // ... implement other node types
        default:
            return ""
        }
    }
}
```

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
- 🎨 **Syntax highlighting**: Code block language support

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