# KaTeX Math Rendering Guide

Render mathematical expressions in Markdown using [KaTeX](https://katex.org/) syntax.

## Syntax

### Inline Math

Use single dollar signs for inline math:

```markdown
Euler's identity: $e^{i\pi} + 1 = 0$
```

### Display Math

Use double dollar signs for display (block) math:

```markdown
$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$
```

## HTML Rendering

### Basic Usage

```swift
import SwiftMarkdownParser

let markdown = """
The quadratic formula is $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$.

$$
\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}
$$
"""

let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTMLWithMath(markdown)
```

### Custom Configuration

```swift
let config = KaTeXConfiguration(
    enabled: true,
    renderMode: .cdn(version: "0.16.21"),
    throwOnError: false,
    errorColor: "#cc0000",
    displayMode: false,
    customCSS: ".math-display { background: #f5f5f5; padding: 1em; }"
)

let html = try await parser.parseToHTMLWithMath(markdown, katexConfiguration: config)
```

### Using RenderContext

```swift
let context = RenderContext(
    katexConfiguration: KaTeXConfiguration(
        throwOnError: true,
        errorColor: "#ff0000"
    )
)

let html = try await parser.parseToHTML(markdown, context: context)
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | `Bool` | `true` | Enable/disable KaTeX rendering |
| `renderMode` | `RenderMode` | `.cdn(version: "0.16.21")` | CDN or custom URL for KaTeX library |
| `throwOnError` | `Bool` | `false` | Throw on KaTeX rendering errors |
| `errorColor` | `String` | `"#cc0000"` | Color for error messages |
| `minRuleThickness` | `Double?` | `nil` | Minimum thickness of fraction lines (in em) |
| `displayMode` | `Bool` | `false` | Default display mode |
| `customCSS` | `String?` | `nil` | Custom CSS for math elements |

## Render Modes

### CDN (Default)

Loads KaTeX from jsDelivr CDN (requires internet):

```swift
let config = KaTeXConfiguration(renderMode: .cdn(version: "0.16.21"))
```

### Custom URL

Use a local or alternative CDN source:

```swift
let config = KaTeXConfiguration(renderMode: .custom(url: "https://my-cdn.com/katex"))
```

## KaTeX Renderer (Low-Level)

For direct control over math rendering:

```swift
let renderer = KaTeXRenderer(configuration: .default)

// Render a math block node
let blockHTML = renderer.renderMathBlock(mathBlockNode)
// Output: <div class="math math-display">...</div>

// Render an inline math node
let inlineHTML = renderer.renderInlineMath(inlineMathNode)
// Output: <span class="math math-inline">...</span>

// Generate KaTeX head content (CSS + JS + init script)
let headContent = renderer.generateKaTeXHeadContent()

// Generate a standalone HTML document with math support
let fullHTML = renderer.generateStandaloneHTML(content: bodyHTML, title: "Math Doc")
```

## WebView Integration

Use `WebViewSupport` for complete HTML documents with math:

```swift
let htmlDocument = try await WebViewSupport.generateMarkdownHTMLDocument(
    markdown,
    title: "Math Document",
    includeMathSupport: true
)
```

## AST Nodes

Math expressions produce two AST node types:

- **`AST.InlineMathNode`** — inline math (`$...$`), contains a `content` string
- **`AST.MathBlockNode`** — display math (`$$...$$`), contains a `content` string
