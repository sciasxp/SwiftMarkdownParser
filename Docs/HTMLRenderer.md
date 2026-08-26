# HTML Renderer Guide

`HTMLRenderer` owns HTML escaping, GFM output, syntax highlighting, Mermaid,
KaTeX, CSS, scripts, and complete-document composition. Its input is always a
completed `AST.DocumentNode`.

## Fragment and complete-document output

```swift
import SwiftMarkdownParser

let parser = SwiftMarkdownParser()
let document = try parser.parse("# Hello **World**")
let renderer = HTMLRenderer()

let fragment = try await renderer.renderFragment(document)
let completeDocument = try await renderer.renderDocument(
    document,
    metadata: HTMLDocumentMetadata(title: "Hello", language: "en")
)
```

`renderFragment(_:)` produces embeddable HTML. `renderDocument(_:metadata:)`
places CSS and feature resources in `<head>` and returns a complete document
suitable for WebKit or export.

## Output options

```swift
let options = HTMLRenderOptions(
    baseURL: URL(string: "https://example.com/docs/"),
    sanitizeHTML: true,
    styleConfiguration: HTMLStyleConfiguration(
        cssClasses: [
            .heading: "custom-heading",
            .paragraph: "content-text",
            .codeBlock: "highlight",
        ],
        includeSourcePositions: true,
        syntaxHighlighting: HTMLSyntaxHighlightingOptions(enabled: true)
    ),
    mermaidConfiguration: MermaidConfiguration(theme: .dark),
    katexConfiguration: KaTeXConfiguration(
        renderMode: .cdn(version: "0.16.21"),
        throwOnError: false
    )
)

let html = try await HTMLRenderer(options: options).renderFragment(document)
```

Mermaid themes are selected through `MermaidConfiguration.Theme`: `.default`,
`.dark`, `.forest`, `.neutral`, and `.base`. Use
`MermaidConfiguration.darkHighContrast` for the high-contrast preset.

## WebView presentation

On macOS, `MarkdownWebView` accepts the same completed document and options:

```swift
MarkdownWebView(
    document: document,
    options: options,
    metadata: HTMLDocumentMetadata(title: "Preview")
)
```

Parsing stays outside the view, so callers can parse once and reuse the same
document for HTML, native SwiftUI, traversal, rewriting, and export.
