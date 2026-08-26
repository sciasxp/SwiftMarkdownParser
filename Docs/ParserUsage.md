# SwiftMarkdownParser Usage Guide

Complete reference for parsing Markdown and working with the AST.

## Basic Usage

```swift
import SwiftMarkdownParser

// Create parser
let parser = SwiftMarkdownParser()

// Build a complete semantic Markdown Document
let document = try parser.parse("# Hello **World**!")

// Parse directly to HTML
let html = try await parser.parseToHTML("# Hello **World**!")
```

## Supported Dialect and Resource Limits

The parser always recognizes CommonMark 0.30, GitHub Flavored Markdown,
math expressions, and Mermaid fenced diagrams. Grammar modes are intentionally
not configurable. Consumers customize results by transforming the completed
document.

```swift
let limits = SwiftMarkdownParser.ResourceLimits(
    maximumSourceLength: 2_000_000,
    maximumNestingDepth: 100,
    maximumWork: 25_000_000
)

let parser = SwiftMarkdownParser(resourceLimits: limits)
```

Limits are deterministic: the same source and limits produce the same result.
Wall-clock time is not part of parsing correctness.

## AST Structure

The parser generates a hierarchical AST with these main node types:

### Common Nodes
- `AST.DocumentNode` - Root document node
- `AST.HeadingNode` - Headings (# ## ###)
- `AST.ParagraphNode` - Text paragraphs
- `AST.TextNode` - Plain text content
- `AST.EmphasisNode` - *italic* text
- `AST.StrongEmphasisNode` - **bold** text
- `AST.LinkNode` - [text](url) links
- `AST.ImageNode` - ![alt](src) images
- `AST.CodeBlockNode` - ```code``` blocks
- `AST.CodeSpanNode` - `code` spans
- `AST.ListNode` - Ordered/unordered lists
- `AST.ListItemNode` - List items
- `AST.BlockQuoteNode` - > blockquotes

### GFM Extension Nodes
- `AST.GFMTableNode` - Pipe-separated tables
- `AST.GFMTableRowNode` - Table rows  
- `AST.GFMTableCellNode` - Table cells
- `AST.GFMTaskListItemNode` - [x] task lists
- `AST.StrikethroughNode` - ~~strikethrough~~

## Working with AST

```swift
let parser = SwiftMarkdownParser()
let ast = try parser.parse(markdown)

func analyzeDocument(_ node: ASTNode) {
    switch node {
    case let heading as AST.HeadingNode:
        print("Heading level \(heading.level)")
    case let link as AST.LinkNode:
        print("Link: \(link.url)")
    case let codeBlock as AST.CodeBlockNode:
        print("Code: \(codeBlock.language ?? "plain")")
    case let table as AST.GFMTableNode:
        print("Table: \(table.rows.count) rows")
    default:
        break
    }
    
    // Process children recursively
    for child in node.children {
        analyzeDocument(child)
    }
}

analyzeDocument(ast)
```

## Error Handling

```swift
do {
    let document = try parser.parse(markdown)
} catch MarkdownParsingError.sourceTooLarge(let limit, let actual) {
    print("Source has \(actual) characters; limit is \(limit)")
} catch MarkdownParsingError.resourceLimitExceeded(let resource, let limit, let actual) {
    print("Exceeded \(resource.rawValue): \(actual) > \(limit)")
} catch {
    print("Parsing failed: \(error)")
}
```

## Performance Tips

- Use the default resource limits for most documents.
- Raise source or work limits deliberately for trusted large inputs.
- Parse once and render or analyze the completed document multiple times.
- Track wall-clock performance in benchmarks, not pass/fail assertions.
