# HTML Renderer Guide

Generate clean HTML output from Markdown with syntax highlighting, theming, math support, and custom styling.

## Basic Usage

```swift
import SwiftMarkdownParser

let parser = SwiftMarkdownParser()
let html = try await parser.parseToHTML("# Hello **World**")
```

## Themed HTML Variants

Convenience methods apply Mermaid diagram themes to the output:

```swift
let parser = SwiftMarkdownParser()

// Dark theme
let darkHTML = try await parser.parseToHTMLWithDarkTheme(markdown)

// Dark high-contrast theme
let hcHTML = try await parser.parseToHTMLWithDarkHighContrastTheme(markdown)

// Forest theme
let forestHTML = try await parser.parseToHTMLWithForestTheme(markdown)

// Neutral theme
let neutralHTML = try await parser.parseToHTMLWithNeutralTheme(markdown)

// Base theme
let baseHTML = try await parser.parseToHTMLWithBaseTheme(markdown)
```

## Custom Context

Use `RenderContext` to control rendering behavior:

```swift
let context = RenderContext(
    baseURL: URL(string: "https://example.com"),
    sanitizeHTML: true,
    styleConfiguration: StyleConfiguration(
        cssClasses: [
            .heading: "custom-heading",
            .paragraph: "content-text",
            .codeBlock: "highlight"
        ]
    )
)

let html = try await parser.parseToHTML(markdown, context: context)
```

## Syntax Highlighting

HTML renderer includes automatic syntax highlighting for:
- JavaScript, TypeScript, Swift, Kotlin, Python, Bash

```swift
let codeMarkdown = """
```swift
let parser = SwiftMarkdownParser()
```
"""

let html = try await parser.parseToHTML(codeMarkdown)
// Returns HTML with syntax highlighting CSS classes
```

## Math Rendering (KaTeX)

Math expressions are rendered with KaTeX support:

```swift
let mathMarkdown = """
Euler's identity: $e^{i\pi} + 1 = 0$

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$
"""

// Default KaTeX configuration
let html = try await parser.parseToHTMLWithMath(mathMarkdown)

// Custom KaTeX configuration
let config = KaTeXConfiguration(
    renderMode: .cdn(version: "0.16.21"),
    throwOnError: false
)
let html = try await parser.parseToHTMLWithMath(mathMarkdown, katexConfiguration: config)
```

See [KaTeX Usage Guide](KaTeXUsage.md) for details.

## Mermaid Diagrams

```swift
let diagramMarkdown = """
```mermaid
graph LR
    A --> B
```
"""

let html = try await parser.parseToHTML(diagramMarkdown)
// Includes Mermaid diagram integration
```

See [Mermaid Usage Guide](MermaidUsage.md) for details.

## GFM Tables

Tables are rendered automatically from GFM pipe syntax:

```swift
let tableMarkdown = """
| Feature | Status |
|---------|--------|
| Tables  | Done   |
| Lists   | Done   |
"""

let html = try await parser.parseToHTML(tableMarkdown)
// Renders <table> with proper alignment attributes
```

## Task Lists

GFM task list items render as checkboxes:

```swift
let taskMarkdown = """
- [x] Completed task
- [ ] Pending task
"""

let html = try await parser.parseToHTML(taskMarkdown)
// Renders with checkbox inputs
```

## Footnotes

Footnote references and definitions are rendered with back-links:

```swift
let footnoteMarkdown = """
This has a footnote[^1].

[^1]: This is the footnote content.
"""

let html = try await parser.parseToHTML(footnoteMarkdown)
```

## WebView HTML Documents

Generate complete HTML documents for `WKWebView` rendering:

```swift
let htmlDocument = try await WebViewSupport.generateMarkdownHTMLDocument(
    markdown,
    title: "My Document",
    includeMathSupport: true,
    includeTaskListSupport: true
)
```
