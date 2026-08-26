# KaTeX Math Rendering Guide

Inline `$...$` and display `$$...$$` expressions become semantic math nodes.
`HTMLRenderer` owns their HTML containers and the KaTeX resources required by
complete documents.

```swift
import SwiftMarkdownParser

let markdown = """
The quadratic formula is $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$.

$$
\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}
$$
"""

let document = try SwiftMarkdownParser().parse(markdown)
let html = try await HTMLRenderer().renderDocument(
    document,
    metadata: HTMLDocumentMetadata(title: "Math Document")
)
```

## Configuration

```swift
let configuration = KaTeXConfiguration(
    enabled: true,
    assetSource: .bundled,
    throwOnError: false,
    errorColor: "#cc0000",
    minRuleThickness: nil,
    customCSS: ".math-display { padding: 1em; }"
)

let options = HTMLRenderOptions(katexConfiguration: configuration)
let html = try await HTMLRenderer(options: options).renderDocument(document)
```

`assetSource` accepts `.bundled`, `.cdn(version:)`, or `.custom(baseURL:)`.
Bundled mode inlines KaTeX, its stylesheet, and WOFF2 fonts so the document
remains portable and works offline. Setting `enabled` to `false` omits KaTeX.
Resources are included once and only when the document contains math.

## AST nodes

- `AST.InlineMathNode` represents inline `$...$` expressions.
- `AST.MathBlockNode` represents display `$$...$$` expressions.

Use `renderFragment(_:)` for embeddable markup and
`renderDocument(_:metadata:)` when a complete document with correctly placed
KaTeX assets is required.
