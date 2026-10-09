# SwiftMarkdownParser Usage Guide

Complete reference for parsing Markdown and working with the AST.

## Basic Usage

```swift
import SwiftMarkdownParser

// Create parser
let parser = SwiftMarkdownParser()

// Build a complete semantic Markdown Document
let document = try parser.parse("# Hello **World**!")

// Feed that document to an output-specific renderer
let html = try await HTMLRenderer().renderFragment(document)
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
- `AST.ThematicBreakNode` - `---` horizontal rules
- `AST.LineBreakNode` / `AST.SoftBreakNode` - hard and soft line breaks
- `AST.AutolinkNode` - `<https://example.com>` and bare-URL autolinks
- `AST.HTMLBlockNode` / `AST.HTMLInlineNode` - raw HTML

### GFM Extension Nodes
- `AST.GFMTableNode` - Pipe-separated tables
- `AST.GFMTableRowNode` - Table rows  
- `AST.GFMTableCellNode` - Table cells
- `AST.GFMTaskListItemNode` - [x] task lists
- `AST.StrikethroughNode` - ~~strikethrough~~
- `AST.FootnoteReferenceNode` / `AST.FootnoteDefinitionNode` - `[^1]` footnotes

### Rich Content Nodes
- `AST.InlineMathNode` / `AST.MathBlockNode` - `$...$` and `$$...$$` math
- `AST.MermaidDiagramNode` - ```` ```mermaid ```` diagram blocks

## Working with AST

```swift
let parser = SwiftMarkdownParser()
let document = try parser.parse(markdown)

for visit in document.depthFirst() {
    switch visit.node {
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
}
```

Traversal is lazy, includes the root, and preserves child order. Every visit
also provides `ancestors`, `parent`, `path`, and `depth`.

To flatten inline content to text (text, code spans, autolinks, image alt
text, and raw HTML, in document order), use
`AST.GFMTableCellNode.extractPlainText(from:)`:

```swift
let title = AST.GFMTableCellNode.extractPlainText(from: heading.children)
```

Nodes carry an optional `SourceLocation` (1-based line/column, 0-based offset,
exclusive end). `location.extending(over: text)` returns a range that starts at
`location` and covers `text`; `start.spanning(to: end)` returns the range from
`start` through the end of `end`.

## Rewriting a Document

`rewriting(_:)` performs one immutable bottom-up pass. A container visit sees
its already-rewritten descendants. Replacement nodes are not visited again in
the same pass.

```swift
let rewritten = try document.rewriting { visit in
    guard let link = visit.node as? AST.LinkNode,
          link.url == "https://old.example" else {
        return .keep
    }

    return .replace(AST.LinkNode(
        url: "https://new.example",
        title: link.title,
        children: link.children,
        sourceLocation: link.sourceLocation
    ))
}
```

Rules return `.keep`, `.remove`, `.replace(node)`, or
`.replaceMany(nodes)`. Built-in containers preserve their metadata when their
children change. Table rows and cells retain their typed relationships;
violations throw `ASTRewriteError`. Existing custom `ASTNode` conformances are
still traversable. A custom node with descendants adopts `ASTRewritableNode`
when those descendants should be rewritable.

## Error Handling

```swift
do {
    let document = try parser.parse(markdown)
} catch MarkdownParsingError.sourceTooLarge(let limit, let actual) {
    print("Source has \(actual) characters; limit is \(limit)")
} catch MarkdownParsingError.resourceLimitExceeded(let resource, let limit, let actual) {
    print("Exceeded \(resource.rawValue): \(actual) > \(limit)")
} catch MarkdownParsingError.internalInvariant(let message, let location) {
    // Parser bug, not a malformed input; please report it.
    print("Internal parser error: \(message) at \(String(describing: location))")
} catch {
    print("Parsing failed: \(error)")
}
```

## Performance Tips

- Use the default resource limits for most documents.
- Raise source or work limits deliberately for trusted large inputs.
- Parse once and render or analyze the completed document multiple times.
- Use `depthFirst()` for generic scans and one `rewriting(_:)` pass for related transformations.
- Track wall-clock performance in benchmarks, not pass/fail assertions.
