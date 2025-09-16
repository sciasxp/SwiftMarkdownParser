# SwiftMarkdownParser Usage Guide

Complete reference for parsing Markdown and working with the AST.

## Basic Usage

```swift
import SwiftMarkdownParser

// Create parser
let parser = SwiftMarkdownParser()

// Parse to AST
let ast = try await parser.parseToAST("# Hello **World**!")

// Parse directly to HTML
let html = try await parser.parseToHTML("# Hello **World**!")
```

## Configuration

```swift
let config = SwiftMarkdownParser.Configuration(
    enableGFMExtensions: true,     // Tables, task lists, strikethrough
    strictMode: false,             // Relaxed parsing
    maxNestingDepth: 100,         // Recursion limit
    trackSourceLocations: false,   // Debug info
    maxParsingTime: 30.0          // Timeout in seconds
)

let parser = SwiftMarkdownParser(configuration: config)
```

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
- `AST.InlineCodeNode` - `code` spans
- `AST.ListNode` - Ordered/unordered lists
- `AST.ListItemNode` - List items
- `AST.BlockQuoteNode` - > blockquotes

### GFM Extension Nodes
- `AST.GFMTableNode` - Pipe-separated tables
- `AST.GFMTableRowNode` - Table rows  
- `AST.GFMTableCellNode` - Table cells
- `AST.GFMTaskListItemNode` - [x] task lists
- `AST.GFMStrikethroughNode` - ~~strikethrough~~

## Working with AST

```swift
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)

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
    let ast = try await parser.parseToAST(markdown)
} catch MarkdownParsingError.invalidInput(let message) {
    print("Invalid input: \(message)")
} catch MarkdownParsingError.tokenizationFailed(let message) {
    print("Tokenization failed: \(message)")
} catch {
    print("Parsing failed: \(error)")
}
```

## Performance Tips

- Use default configuration for most cases
- Increase `maxParsingTime` only for very large documents
- Set `trackSourceLocations: false` for better performance
- Consider parsing to AST once and rendering multiple times