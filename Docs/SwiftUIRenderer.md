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
    @State private var error: Error?

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
    linkHandler: { url in
        // Route the URL through the host application.
    },
    imageHandler: { url in
        AnyView(AsyncImage(url: url))
    }
)

let view = try await SwiftUIRenderer(options: options).render(document)
```

Built-in styles include `.github`, `.minimal`, and `.academic`. A custom
`SwiftUIStyleConfiguration` can control typography, colors, spacing, tables,
task lists, code blocks, and images.

## Supported document content

The native renderer handles CommonMark nodes, GFM tables, task lists,
strikethrough, math fallbacks, and Mermaid diagrams. On macOS, Mermaid uses an
internal WebKit-backed view; other platforms receive the native fallback.

The public interface intentionally renders only complete documents. To render a
single programmatically-created node, place it in a document first:

```swift
let document = AST.DocumentNode(children: [headingNode])
let view = try await SwiftUIRenderer().render(document)
```

## HTML-backed presentation

Use `MarkdownWebView` when the desired output is the HTML renderer displayed by
WebKit rather than native SwiftUI views:

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
