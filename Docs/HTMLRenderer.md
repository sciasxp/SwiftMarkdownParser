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

## Rendering architecture

Body rendering first records the browser behavior actually required by the
document. One internal assembler then selects and deduplicates resources,
places them correctly for fragment or document output, and emits a single
readiness/failure bootstrap.

```text
AST.DocumentNode
    -> escaped HTML body + discovered requirements
    -> browser asset assembly
    -> fragment or complete HTML document
```

The discovered requirements are Mermaid, KaTeX, footnote navigation, and
task-list interaction. Merely enabling a feature does not add its runtime when
the document does not use it. Configuration remains data-only; it never builds
scripts or styles itself.

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
        assetSource: .cdn(version: "0.16.21"),
        throwOnError: false
    )
)

let html = try await HTMLRenderer(options: options).renderFragment(document)
```

Mermaid themes are selected through `MermaidConfiguration.Theme`: `.default`,
`.dark`, `.forest`, `.neutral`, and `.base`. Use
`MermaidConfiguration.darkHighContrast` for the high-contrast preset.

Both browser runtimes support `.bundled`, `.cdn(version:)`, and caller-owned
custom URLs. Bundled resources are inlined into the result for deterministic,
offline HTML. The default remains a pinned CDN source to keep ordinary output
small.

Syntax highlighting does not require a browser runtime. `HTMLRenderer` reuses
one `SyntaxHighlighter` across code blocks and render calls, while its internal
code-block renderer owns escaping and semantic `<span>` assembly. Unsupported
languages or highlighting failures fall back to the original escaped code.

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
`onRender` succeeds only after every required browser runtime reports ready;
navigation or subresource failures are returned through the same callback.

See [Architecture](Architecture.md) for the complete module map and the
decisions behind output-specific renderers and browser enrichment.
