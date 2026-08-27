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

A host that supplies presentation CSS, browser behavior, or addressable content
regions uses the same renderer with one structured assembly value:

```swift
let assembly = HTMLDocumentAssembly(
    metadata: HTMLDocumentMetadata(title: "Preview", language: "pt-BR"),
    styles: [presentationCSS],
    scripts: [presentationJavaScript],
    regions: [
        HTMLDocumentRegion(
            id: "section-1",
            startMarker: "<section-start></section-start>",
            endMarker: "<section-end></section-end>"
        )
    ]
)
let html = try await renderer.renderDocument(document, assembly: assembly)
```

`BrowserDocumentAssembler` validates every region and places host styles and scripts
while it builds the shell. Callers never reopen a completed document to search for
`</head>` or `</body>`. Styles and scripts are trusted host input; Markdown content
continues to follow `sanitizeHTML`.

## Rendering architecture

Body rendering first records the browser behavior actually required by the
document. One internal assembler then selects and deduplicates resources,
places them correctly for fragment or document output, and emits a single
readiness/failure bootstrap.

```text
AST.DocumentNode
    -> escaped HTML body + discovered requirements
    -> browser assets + structured host assembly
    -> fragment or complete HTML document once
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
    includeDefaultStyles: false,
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

Set `includeDefaultStyles` to `false` when a host presentation supplies the
complete visual stylesheet. The renderer still owns document composition,
feature assets, and browser readiness.

The complete document publishes one versioned runtime observation after
initialization. Version 1 contains `status`, the sorted `requiredFeatures`, the
sorted `failedFeatures`, and optional diagnostic `detail`. It is dispatched as
the `swift-markdown-runtime` DOM event and, when present, posted to WebKit's
`markdownRuntime` message handler. The report deliberately has no host attempt
identity or artifact policy.

`failedFeatures` identifies the requirements that could not initialize. A host
can therefore distinguish an exclusive Mermaid failure from a mixed runtime
failure without inferring capability from DOM selectors. Consumers should
reject unknown numbered versions; package-owned legacy WebView decoding alone
continues to accept the former unversioned status/detail payload.

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
navigation or subresource failures are returned through the same callback. The
structured report remains an internal assembly/WebKit seam, so this public
callback is source-compatible.

See [Architecture](Architecture.md) for the complete module map and the
decisions behind output-specific renderers and browser enrichment.
