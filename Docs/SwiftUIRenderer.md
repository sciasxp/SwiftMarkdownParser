# SwiftUI Renderer Guide

`SwiftUIRenderer` is the native output module for iOS 17+ and macOS 14+. It is
`@MainActor` and renders a complete `AST.DocumentNode` into `AnyView`.

## Basic integration

```swift
import SwiftUI
import SwiftMarkdownParser

struct MarkdownView: View {
    let source: String
    @State private var rendered: AnyView?
    @State private var error: (any Error)?

    var body: some View {
        ScrollView {
            if let rendered {
                rendered
            } else if let error {
                ContentUnavailableView(
                    "Unable to render Markdown",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Rendering…")
            }
        }
        .task(id: source) {
            await render()
        }
    }

    @MainActor
    private func render() async {
        do {
            let document = try SwiftMarkdownParser().parse(source)
            rendered = try await SwiftUIRenderer().render(document)
            error = nil
        } catch {
            rendered = nil
            self.error = error
        }
    }
}
```

## Output options

```swift
let options = SwiftUIRenderOptions(
    baseURL: URL(string: "https://example.com/docs/"),
    styleConfiguration: .github,
    mermaidConfiguration: MermaidConfiguration(theme: .dark),
    syntaxHighlightingTheme: .xcode,
    richContentAdapter: SwiftUIRichContentAdapter { request in
        switch request {
        case let .mermaid(node, configuration):
            AnyView(MyMermaidView(source: node.content, configuration: configuration))

        case let .mathBlock(node):
            AnyView(MyMathView(source: node.content, displayMode: true))

        case let .image(_, source):
            AnyView(AsyncImage(url: source))

        case .inlineMath, .htmlBlock, .htmlInline:
            nil
        }
    },
    linkHandler: { url in
        // Route the URL through the host application.
    }
)

let view = try await SwiftUIRenderer(options: options).render(document)
```

Built-in styles include `.github`, `.minimal`, and `.academic`. A custom
`SwiftUIStyleConfiguration` can control typography, colors, spacing, tables,
task lists, code blocks, and images. Semantic code highlighting is opt-in via
`syntaxHighlightingTheme`; `.github`, `.xcode`, and `.vsCodeDark` are included.
Unsupported and unlabelled languages retain the plain code style without losing
source text.

## Atomic document projection

Before producing any view, `SwiftUIRenderer` interprets and validates the whole
document in deterministic depth-first order. This first phase creates a typed,
one-shot native plan containing block structure, inline meaning, and deferred
rich-content requests. It does not allocate view identity, invoke the host rich
content adapter, or perform syntax highlighting.

Materialization starts only after the complete plan succeeds. Consequently, an
unsupported node cannot leave behind a partial native view graph or an earlier
host-adapter effect, including when the unsupported node is nested inside inline
formatting, a list, a quote, a table, or a footnote. If several nodes are
unsupported, the first one in depth-first document order is reported.

The plan uses temporary memory proportional to the document. It is consumed by
one render and then discarded; the public renderer interface and the returned
view remain unchanged.

GFM tables are normalized during this phase. The first row is the only possible
column-header source, table-level alignments define the column schema, and all
remaining rows preserve their cell order. Missing headers and alignments remain
explicit instead of being inferred later. Cell-level header and alignment
fields are retained by the public AST for compatibility but are not competing
renderer inputs.

## Adaptive native presentation

The returned view is container-aware. It does not assume a device class or read
global screen bounds. Native lists, task rows, block quotes, footnotes, tables,
and Mermaid fallbacks adapt to the width proposed by their host and to
accessibility Dynamic Type categories.

Tables use a dense aligned grid while it fits. In narrow containers, or at an
accessibility text size, the same projected columns and data cells become
labeled rows that keep optional column headers beside their values. A table with
only headers remains a grid, while a table without headers stacks values without
inventing labels. Rich inline adapters, including header content reused by many
rows, are materialized once; choosing a presentation does not reinvoke host
adapters.

List markers, task states, footnote identifiers, Mermaid titles, and stacked
table fields share one label/content module. The renderer materializes your
`SwiftUIStyleConfiguration` once into an internal presentation style, which
derives each relationship's spacing, minimum content width, alignment, and
horizontal-to-vertical policy from your metrics without exposing thresholds to
callers. The module keeps measurement and placement on one finite geometry plan, aligns
textual pairs by first baseline when available, mirrors placement for
right-to-left layouts, and constrains oversized labels to their container.
VoiceOver copy and grouping remain owned by native semantics and the presenting
view rather than inferred from visual placement.

The Mermaid fallback keeps its source visible and wraps it within the proposed
container instead of depending on an unbounded horizontal scroll measurement.

Native content is materialized before SwiftUI evaluates `body`. One internal
owner assigns stable identity to document children, list items, table rows and
cells, and rich inline fragments. Adaptive alternatives reuse those concrete
unary views, so layout selection does not regenerate identity or repeat type
erasure.

## Native semantics and localization

Visible fallback titles, renderer errors, and VoiceOver labels are resolved from
the Swift package resource bundle. English is the source language and Brazilian
Portuguese is included. Resolution remains deferred through
`LocalizedStringResource`, so a host-provided SwiftUI locale also applies to the
renderer's native semantic text.

Markdown content is never treated as a localization key. Source text, image
alternative text, footnote identifiers, code-language names, and Mermaid types
remain verbatim values interpolated into complete translator-reorderable
messages.

## Supported document content

The native renderer handles CommonMark nodes, GFM tables, task lists,
strikethrough, footnotes, wrapping formatted links, relative image URLs, and
semantic code highlighting. Raw HTML, math, and Mermaid have readable,
accessible source fallbacks. Applications that need visual rendering for those
formats provide one `SwiftUIRichContentAdapter`. Its single `render(_:)`
operation receives a typed request and may return `nil` to retain the native
fallback. Image requests cross this seam only after their destination has been
resolved and validated by the rich-content module. Native link destinations
remain part of inline projection and may still wrap an accessible image
fallback. This keeps WebKit, KaTeX, Mermaid, or another rendering dependency
under host ownership on both iOS and macOS without distributing image or
fallback policy across per-node closures.

The public interface intentionally renders only complete documents. To render a
single programmatically-created node, place it in a document first:

```swift
let document = AST.DocumentNode(children: [headingNode])
let view = try await SwiftUIRenderer().render(document)
```

## HTML-backed presentation

On macOS, use `MarkdownWebView` when the desired output is the complete HTML
renderer displayed by WebKit rather than native SwiftUI views:

```swift
MarkdownWebView(
    document: document,
    options: HTMLRenderOptions(),
    metadata: HTMLDocumentMetadata(title: "Preview")
)
```

Both output paths consume the same immutable AST, so parsing, traversal, and
rewriting remain independent from presentation.

## Interface

```swift
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct SwiftUIRenderer {
    public let options: SwiftUIRenderOptions

    public init(options: SwiftUIRenderOptions = .init())
    public func render(_ document: AST.DocumentNode) async throws -> AnyView
}
```
