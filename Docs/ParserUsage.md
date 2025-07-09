# Parser Usage Documentation

Complete guide to using SwiftMarkdownParser for parsing markdown into Abstract Syntax Trees (AST) and advanced parser configuration.

## Table of Contents

- [Quick Start](#quick-start)
- [Parser Configuration](#parser-configuration)
- [AST Structure](#ast-structure)
- [Working with AST Nodes](#working-with-ast-nodes)
- [AST Traversal and Analysis](#ast-traversal-and-analysis)
- [Custom Node Processing](#custom-node-processing)
- [Error Handling](#error-handling)
- [Performance Optimization](#performance-optimization)
- [Advanced Use Cases](#advanced-use-cases)
- [API Reference](#api-reference)

## Quick Start

```swift
import SwiftMarkdownParser

// Basic parsing
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST("# Hello **World**!")

// Working with the AST
if let document = ast as? AST.DocumentNode {
    print("Document has \(document.children.count) top-level elements")
}
```

## Parser Configuration

### Basic Configuration

```swift
let config = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true,      // GitHub Flavored Markdown
    strictMode: false,              // Relaxed parsing rules
    maxNestingDepth: 100,          // Prevent infinite recursion
    trackSourceLocations: true     // Include position information
)

let parser = SwiftMarkdownParser(configuration: config)
```

### Configuration Options Explained

#### GFM Extensions

```swift
// Enable GitHub Flavored Markdown features
let gfmConfig = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true
)

// Supported GFM features:
// - Tables
// - Task lists
// - Strikethrough text
// - Autolinks
// - Table alignment

let markdown = """
| Feature | Status |
|---------|--------|
| Tables | ✅ |
| Task Lists | ✅ |

- [x] Completed task
- [ ] Pending task

~~Deprecated feature~~
"""

let ast = try await parser.parseToAST(markdown)
```

#### Strict Mode

```swift
// Strict CommonMark compliance
let strictConfig = SwiftMarkdownParser.Configuration(
    strictMode: true
)

// Relaxed mode (default) - more forgiving parsing
let relaxedConfig = SwiftMarkdownParser.Configuration(
    strictMode: false
)
```

#### Source Location Tracking

```swift
let config = SwiftMarkdownParser.Configuration(
    trackSourceLocations: true
)

let parser = SwiftMarkdownParser(configuration: config)
let ast = try await parser.parseToAST(markdown)

// Access source locations
func printSourceLocations(_ node: ASTNode, indent: Int = 0) {
    let indentString = String(repeating: "  ", count: indent)
    
    if let location = node.sourceLocation {
        print("\(indentString)\(node.nodeType) at line \(location.line), column \(location.column)")
    } else {
        print("\(indentString)\(node.nodeType) (no location)")
    }
    
    for child in node.children {
        printSourceLocations(child, indent: indent + 1)
    }
}

printSourceLocations(ast)
```

## AST Structure

### Document Structure

```swift
// Every parsed document is a DocumentNode containing child nodes
let ast = try await parser.parseToAST(markdown)
print("AST type: \(type(of: ast))")  // AST.DocumentNode

// Access children
for child in ast.children {
    print("Child type: \(child.nodeType)")
}
```

### Node Hierarchy

```
DocumentNode
├── HeadingNode
│   └── TextNode
├── ParagraphNode
│   ├── TextNode
│   ├── EmphasisNode
│   │   └── TextNode
│   └── StrongEmphasisNode
│       └── TextNode
└── ListNode
    ├── ListItemNode
    │   └── TextNode
    └── ListItemNode
        └── TextNode
```

### Node Types

```swift
public enum ASTNodeType: String, CaseIterable, Sendable {
    // Block elements
    case document = "document"
    case paragraph = "paragraph"
    case heading = "heading"
    case blockQuote = "block_quote"
    case list = "list"
    case listItem = "list_item"
    case codeBlock = "code_block"
    case thematicBreak = "thematic_break"
    case htmlBlock = "html_block"
    
    // Inline elements
    case text = "text"
    case emphasis = "emphasis"
    case strongEmphasis = "strong_emphasis"
    case link = "link"
    case image = "image"
    case codeSpan = "code_span"
    case lineBreak = "line_break"
    case softBreak = "soft_break"
    case htmlInline = "html_inline"
    case autolink = "autolink"
    
    // GFM extensions
    case table = "table"
    case tableRow = "table_row"
    case tableCell = "table_cell"
    case taskListItem = "task_list_item"
    case strikethrough = "strikethrough"
}
```

## Working with AST Nodes

### Type Checking and Casting

```swift
func processNode(_ node: ASTNode) {
    switch node {
    case let heading as AST.HeadingNode:
        print("Heading level \(heading.level)")
        
    case let paragraph as AST.ParagraphNode:
        print("Paragraph with \(paragraph.children.count) children")
        
    case let text as AST.TextNode:
        print("Text: '\(text.content)'")
        
    case let link as AST.LinkNode:
        print("Link to: \(link.url)")
        if let title = link.title {
            print("Link title: \(title)")
        }
        
    case let image as AST.ImageNode:
        print("Image: \(image.url)")
        print("Alt text: \(image.altText)")
        
    case let codeBlock as AST.CodeBlockNode:
        print("Code block (\(codeBlock.language ?? "plain")):")
        print(codeBlock.content)
        
    case let list as AST.ListNode:
        print("\(list.isOrdered ? "Ordered" : "Unordered") list")
        
    case let table as AST.GFMTableNode:
        print("Table with \(table.rows.count) rows")
        print("Alignments: \(table.alignments)")
        
    case let taskItem as AST.GFMTaskListItemNode:
        print("Task: \(taskItem.isChecked ? "✅" : "❌")")
        
    default:
        print("Unknown node type: \(node.nodeType)")
    }
}
```

### Node Properties

```swift
// Common properties available on all nodes
extension ASTNode {
    var nodeType: ASTNodeType { get }
    var children: [ASTNode] { get }
    var sourceLocation: SourceLocation? { get }
}

// Specific node properties
func exploreNodeProperties(_ node: ASTNode) {
    if let heading = node as? AST.HeadingNode {
        print("Heading level: \(heading.level)")
    }
    
    if let link = node as? AST.LinkNode {
        print("URL: \(link.url)")
        print("Title: \(link.title ?? "none")")
    }
    
    if let image = node as? AST.ImageNode {
        print("Image URL: \(image.url)")
        print("Alt text: \(image.altText)")
        print("Title: \(image.title ?? "none")")
    }
    
    if let codeBlock = node as? AST.CodeBlockNode {
        print("Language: \(codeBlock.language ?? "none")")
        print("Content length: \(codeBlock.content.count)")
    }
    
    if let list = node as? AST.ListNode {
        print("Ordered: \(list.isOrdered)")
        print("Start number: \(list.startNumber ?? 1)")
        print("Items: \(list.items.count)")
    }
}
```

## AST Traversal and Analysis

### Recursive Traversal

```swift
func traverseAST(_ node: ASTNode, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    print("\(indent)\(node.nodeType): \(nodeDescription(node))")
    
    for child in node.children {
        traverseAST(child, depth: depth + 1)
    }
}

func nodeDescription(_ node: ASTNode) -> String {
    switch node {
    case let text as AST.TextNode:
        return "'\(text.content)'"
    case let heading as AST.HeadingNode:
        return "level \(heading.level)"
    case let link as AST.LinkNode:
        return "→ \(link.url)"
    case let codeBlock as AST.CodeBlockNode:
        return codeBlock.language ?? "plain"
    default:
        return ""
    }
}
```

### Finding Specific Nodes

```swift
// Find all headings
func findHeadings(in node: ASTNode) -> [AST.HeadingNode] {
    var headings: [AST.HeadingNode] = []
    
    if let heading = node as? AST.HeadingNode {
        headings.append(heading)
    }
    
    for child in node.children {
        headings.append(contentsOf: findHeadings(in: child))
    }
    
    return headings
}

// Find all links
func findLinks(in node: ASTNode) -> [AST.LinkNode] {
    var links: [AST.LinkNode] = []
    
    if let link = node as? AST.LinkNode {
        links.append(link)
    }
    
    for child in node.children {
        links.append(contentsOf: findLinks(in: child))
    }
    
    return links
}

// Generic node finder
func findNodes<T: ASTNode>(of type: T.Type, in node: ASTNode) -> [T] {
    var results: [T] = []
    
    if let typedNode = node as? T {
        results.append(typedNode)
    }
    
    for child in node.children {
        results.append(contentsOf: findNodes(of: type, in: child))
    }
    
    return results
}

// Usage
let ast = try await parser.parseToAST(markdown)
let headings = findNodes(of: AST.HeadingNode.self, in: ast)
let links = findNodes(of: AST.LinkNode.self, in: ast)
```

### Document Analysis

```swift
struct DocumentAnalysis {
    let wordCount: Int
    let headingCount: Int
    let linkCount: Int
    let imageCount: Int
    let codeBlockCount: Int
    let tableCount: Int
    let headingLevels: [Int: Int]  // level -> count
    let languages: Set<String>    // code block languages
}

func analyzeDocument(_ document: AST.DocumentNode) -> DocumentAnalysis {
    var wordCount = 0
    var headingCount = 0
    var linkCount = 0
    var imageCount = 0
    var codeBlockCount = 0
    var tableCount = 0
    var headingLevels: [Int: Int] = [:]
    var languages: Set<String> = []
    
    func analyze(_ node: ASTNode) {
        switch node {
        case let text as AST.TextNode:
            wordCount += text.content.split(separator: " ").count
            
        case let heading as AST.HeadingNode:
            headingCount += 1
            headingLevels[heading.level, default: 0] += 1
            
        case _ as AST.LinkNode:
            linkCount += 1
            
        case _ as AST.ImageNode:
            imageCount += 1
            
        case let codeBlock as AST.CodeBlockNode:
            codeBlockCount += 1
            if let language = codeBlock.language {
                languages.insert(language)
            }
            
        case _ as AST.GFMTableNode:
            tableCount += 1
            
        default:
            break
        }
        
        for child in node.children {
            analyze(child)
        }
    }
    
    analyze(document)
    
    return DocumentAnalysis(
        wordCount: wordCount,
        headingCount: headingCount,
        linkCount: linkCount,
        imageCount: imageCount,
        codeBlockCount: codeBlockCount,
        tableCount: tableCount,
        headingLevels: headingLevels,
        languages: languages
    )
}

// Usage
let analysis = analyzeDocument(ast)
print("Document contains \(analysis.wordCount) words")
print("Heading distribution: \(analysis.headingLevels)")
```

## Custom Node Processing

### AST Transformation

```swift
// Transform AST nodes
func transformAST(_ node: ASTNode) -> ASTNode {
    switch node {
    case let heading as AST.HeadingNode:
        // Convert all headings to lowercase
        let transformedChildren = heading.children.map { transformAST($0) }
        return AST.HeadingNode(
            level: heading.level,
            children: transformedChildren,
            sourceLocation: heading.sourceLocation
        )
        
    case let text as AST.TextNode:
        // Transform text content
        return AST.TextNode(
            content: text.content.lowercased(),
            sourceLocation: text.sourceLocation
        )
        
    case let link as AST.LinkNode:
        // Update link URLs
        let transformedChildren = link.children.map { transformAST($0) }
        return AST.LinkNode(
            url: updateURL(link.url),
            title: link.title,
            children: transformedChildren,
            sourceLocation: link.sourceLocation
        )
        
    default:
        // Recursively transform children
        let transformedChildren = node.children.map { transformAST($0) }
        return createNodeWithTransformedChildren(node, children: transformedChildren)
    }
}

func updateURL(_ url: String) -> String {
    // Add tracking parameters, convert to absolute URLs, etc.
    if url.hasPrefix("/") {
        return "https://mysite.com" + url
    }
    return url
}
```

### Content Extraction

```swift
// Extract plain text from AST
func extractText(from node: ASTNode) -> String {
    if let textNode = node as? AST.TextNode {
        return textNode.content
    }
    
    return node.children
        .map { extractText(from: $0) }
        .joined(separator: "")
}

// Extract specific content types
func extractCodeBlocks(from document: AST.DocumentNode) -> [String] {
    let codeBlocks = findNodes(of: AST.CodeBlockNode.self, in: document)
    return codeBlocks.map { $0.content }
}

func extractHeadingsText(from document: AST.DocumentNode) -> [String] {
    let headings = findNodes(of: AST.HeadingNode.self, in: document)
    return headings.map { extractText(from: $0) }
}

func extractLinks(from document: AST.DocumentNode) -> [(text: String, url: String)] {
    let links = findNodes(of: AST.LinkNode.self, in: document)
    return links.map { 
        (text: extractText(from: $0), url: $0.url)
    }
}
```

### AST Validation

```swift
func validateAST(_ node: ASTNode) -> [ValidationError] {
    var errors: [ValidationError] = []
    
    // Validate structure
    if let document = node as? AST.DocumentNode {
        if document.children.isEmpty {
            errors.append(.emptyDocument)
        }
    }
    
    // Validate links
    if let link = node as? AST.LinkNode {
        if !isValidURL(link.url) {
            errors.append(.invalidURL(link.url))
        }
    }
    
    // Validate images
    if let image = node as? AST.ImageNode {
        if image.altText.isEmpty {
            errors.append(.missingAltText(image.url))
        }
    }
    
    // Validate headings
    if let heading = node as? AST.HeadingNode {
        if heading.level < 1 || heading.level > 6 {
            errors.append(.invalidHeadingLevel(heading.level))
        }
    }
    
    // Recursively validate children
    for child in node.children {
        errors.append(contentsOf: validateAST(child))
    }
    
    return errors
}

enum ValidationError: Error {
    case emptyDocument
    case invalidURL(String)
    case missingAltText(String)
    case invalidHeadingLevel(Int)
}

func isValidURL(_ string: String) -> Bool {
    URL(string: string) != nil
}
```

## Error Handling

### Common Parsing Errors

```swift
func parseWithErrorHandling(_ markdown: String) async {
    do {
        let parser = SwiftMarkdownParser()
        let ast = try await parser.parseToAST(markdown)
        print("Parsing successful")
        
    } catch MarkdownParserError.invalidInput(let message) {
        print("Invalid input: \(message)")
        
    } catch MarkdownParserError.malformedMarkdown(let message, let location) {
        if let location = location {
            print("Malformed markdown at line \(location.line): \(message)")
        } else {
            print("Malformed markdown: \(message)")
        }
        
    } catch MarkdownParserError.nestingTooDeep(let depth) {
        print("Nesting too deep: \(depth) levels")
        
    } catch MarkdownParserError.unsupportedFeature(let feature) {
        print("Unsupported feature: \(feature)")
        
    } catch MarkdownParserError.internalError(let message) {
        print("Internal parser error: \(message)")
        
    } catch {
        print("Unknown parsing error: \(error)")
    }
}
```

### Error Recovery

```swift
func parseWithFallback(_ markdown: String) async -> AST.DocumentNode {
    do {
        let parser = SwiftMarkdownParser()
        return try await parser.parseToAST(markdown)
        
    } catch {
        print("Parsing failed, creating fallback document")
        
        // Create a simple document with the raw text
        let textNode = AST.TextNode(content: markdown)
        let paragraphNode = AST.ParagraphNode(children: [textNode])
        return AST.DocumentNode(children: [paragraphNode])
    }
}
```

## Performance Optimization

### Batch Processing

```swift
func parseMultipleDocuments(_ markdowns: [String]) async throws -> [AST.DocumentNode] {
    let parser = SwiftMarkdownParser()
    
    return try await withThrowingTaskGroup(of: AST.DocumentNode.self) { group in
        for markdown in markdowns {
            group.addTask {
                try await parser.parseToAST(markdown)
            }
        }
        
        var results: [AST.DocumentNode] = []
        for try await ast in group {
            results.append(ast)
        }
        return results
    }
}
```

### Streaming Processing

```swift
// For very large documents, consider splitting into chunks
func parseInChunks(_ markdown: String, chunkSize: Int = 1000) async throws -> [AST.DocumentNode] {
    let chunks = markdown.chunked(into: chunkSize)
    let parser = SwiftMarkdownParser()
    
    var results: [AST.DocumentNode] = []
    
    for chunk in chunks {
        let ast = try await parser.parseToAST(chunk)
        results.append(ast)
    }
    
    return results
}

extension String {
    func chunked(into size: Int) -> [String] {
        guard size > 0 else { return [self] }
        
        var chunks: [String] = []
        var startIndex = self.startIndex
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: size, limitedBy: self.endIndex) ?? self.endIndex
            chunks.append(String(self[startIndex..<endIndex]))
            startIndex = endIndex
        }
        
        return chunks
    }
}
```

## Advanced Use Cases

### Table of Contents Generation

```swift
func generateTableOfContents(_ document: AST.DocumentNode) -> String {
    let headings = findNodes(of: AST.HeadingNode.self, in: document)
    
    var toc = "## Table of Contents\n\n"
    
    for heading in headings {
        let text = extractText(from: heading)
        let id = generateAnchorId(text)
        let indent = String(repeating: "  ", count: heading.level - 1)
        
        toc += "\(indent)- [\(text)](#\(id))\n"
    }
    
    return toc
}

func generateAnchorId(_ text: String) -> String {
    return text.lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
}
```

### Link Validation

```swift
func validateLinks(in document: AST.DocumentNode) async -> [LinkValidationResult] {
    let links = findNodes(of: AST.LinkNode.self, in: document)
    
    return await withTaskGroup(of: LinkValidationResult.self) { group in
        for link in links {
            group.addTask {
                await validateLink(link)
            }
        }
        
        var results: [LinkValidationResult] = []
        for await result in group {
            results.append(result)
        }
        return results
    }
}

func validateLink(_ link: AST.LinkNode) async -> LinkValidationResult {
    guard let url = URL(string: link.url) else {
        return LinkValidationResult(url: link.url, isValid: false, error: "Invalid URL format")
    }
    
    do {
        let (_, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        
        return LinkValidationResult(
            url: link.url,
            isValid: statusCode >= 200 && statusCode < 400,
            error: statusCode >= 400 ? "HTTP \(statusCode)" : nil
        )
    } catch {
        return LinkValidationResult(url: link.url, isValid: false, error: error.localizedDescription)
    }
}

struct LinkValidationResult {
    let url: String
    let isValid: Bool
    let error: String?
}
```

### Word Count and Reading Time

```swift
func calculateReadingStats(_ document: AST.DocumentNode) -> ReadingStats {
    let text = extractText(from: document)
    let words = text.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
    
    let wordCount = words.count
    let averageWPM = 200  // Average reading speed
    let readingTimeMinutes = max(1, wordCount / averageWPM)
    
    let codeBlocks = findNodes(of: AST.CodeBlockNode.self, in: document)
    let codeLines = codeBlocks.reduce(0) { total, codeBlock in
        total + codeBlock.content.components(separatedBy: .newlines).count
    }
    
    return ReadingStats(
        wordCount: wordCount,
        readingTimeMinutes: readingTimeMinutes,
        codeLines: codeLines
    )
}

struct ReadingStats {
    let wordCount: Int
    let readingTimeMinutes: Int
    let codeLines: Int
}
```

## API Reference

### SwiftMarkdownParser

```swift
public final class SwiftMarkdownParser: Sendable {
    public init(configuration: Configuration = .default)
    public func parseToAST(_ markdown: String) async throws -> AST.DocumentNode
    public func parseToHTML(_ markdown: String, context: RenderContext = RenderContext()) async throws -> String
}
```

### Configuration

```swift
public struct Configuration: Sendable {
    public let enableGFMExtensions: Bool
    public let strictMode: Bool
    public let maxNestingDepth: Int
    public let trackSourceLocations: Bool
    
    public init(
        enableGFMExtensions: Bool = true,
        strictMode: Bool = false,
        maxNestingDepth: Int = 100,
        trackSourceLocations: Bool = false
    )
    
    public static let `default`: Configuration
}
```

### Error Types

```swift
public enum MarkdownParserError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case nestingTooDeep(Int)
    case malformedMarkdown(String, SourceLocation?)
    case unsupportedFeature(String)
    case internalError(String)
}
```

### Source Location

```swift
public struct SourceLocation: Sendable, Equatable {
    public let line: Int
    public let column: Int
    public let offset: Int
    
    public init(line: Int, column: Int, offset: Int)
}
```

---

**Next Steps**: Explore the [HTML Renderer Documentation](HTMLRenderer.md) and [SwiftUI Renderer Documentation](SwiftUIRenderer.md) for output formatting options. 