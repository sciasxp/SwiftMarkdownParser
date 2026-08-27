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

## Adaptive native presentation

The returned view is container-aware. It does not assume a device class or read
global screen bounds. Native lists, task rows, block quotes, footnotes, tables,
and Mermaid fallbacks adapt to the width proposed by their host and to
accessibility Dynamic Type categories.

Tables use a dense aligned grid while it fits. In narrow containers, or at an
accessibility text size, the same projected cells become labeled rows that keep
column headers beside their values. Rich inline adapters are materialized once;
choosing a presentation does not reinvoke host adapters.

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
resolved and validated. This keeps WebKit, KaTeX, Mermaid, or another rendering
dependency under host ownership on both iOS and macOS without distributing
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
