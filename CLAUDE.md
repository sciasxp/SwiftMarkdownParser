# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
swift build                                    # Build the library
swift build --build-tests                      # Build including test targets
swift test                                     # Run all tests
swift test --filter HTMLRendererTests           # Run a specific test suite
swift test --filter HTMLRendererTests/testName  # Run a single test
open Package.swift                             # Open in Xcode
```

## Project Overview

SwiftMarkdownParser is a pure Swift markdown parser with zero external dependencies. It supports CommonMark 0.30 and GitHub Flavored Markdown (GFM), with renderers for both HTML and native SwiftUI output.

- **Swift 6.2+**, platforms: macOS 14.0+ / iOS 17.0+
- SPM package producing the `SwiftMarkdownParser` library and a `WebViewTest` example executable

## Architecture: Markdown Document Construction

```
Markdown Source
    → SwiftMarkdownParser.parse(_:)
    → one internal parse execution (tokens, blocks, inlines, references, budgets)
    → complete Markdown Document (DocumentNode with semantic children and source ranges)
    → Renderer                 (HTMLRenderer in SwiftMarkdownParser.swift, or SwiftUIRenderer)
```

**Entry point:** `SwiftMarkdownParser` in `SwiftMarkdownParser.swift` exposes synchronous `parse(_:)`, async HTML conveniences, and deterministic `ResourceLimits`. Token, block, and inline parsers are internal implementation details. The Supported Dialect is fixed to CommonMark 0.30, GFM, math, and Mermaid.

**Renderer protocol:** `MarkdownRenderer` in `RendererProtocol.swift` — generic over `Output` and `Context` types. `RendererRegistry` (actor) manages multiple renderers. GFM table/task-list rendering is implemented as extensions on this protocol.

**SwiftUI rendering:** `SwiftUIRenderer` in `SwiftUIRenderer.swift` and `SwiftUIRenderContext` in `SwiftUIRenderContext.swift` — produces `AnyView` output, requires iOS 17.0+/macOS 14.0+.

## Key Source Directories

- `Sources/SwiftMarkdownParser/` — all library code
  - Core parser: `SwiftMarkdownParser.swift`, `Tokenizer.swift`, `BlockParser.swift`, `InlineParser.swift`, `AST.swift`
  - Renderers: `RendererProtocol.swift`, `SwiftUIRenderer.swift`, `SwiftUIRenderContext.swift`, `MermaidRenderer.swift`, `MermaidConfiguration.swift`, `KaTeXRenderer.swift`, `KaTeXConfiguration.swift`, `WebViewSupport.swift`
  - GFM table utilities: `GFMExtensions.swift`
  - Syntax highlighting: `SyntaxHighlighting.swift` + one `*SyntaxEngine.swift` per language (JS, TS, Swift, Kotlin, Python, Bash)
- `Tests/SwiftMarkdownParserTests/` — Swift Testing suites and repository-owned fixtures
- `Examples/` — `WebViewTest.swift`, `AST_Example.swift`
- `Docs/` — usage guides for HTML rendering, SwiftUI rendering, syntax highlighting, Mermaid, KaTeX

## Gotchas

- **Document construction is synchronous** — call `try parser.parse(source)`; HTML and renderer operations remain `async throws`.
- **Test at the document seam** — use Markdown Source → Markdown Document tests. Direct token tests are reserved for internal progress or budget invariants.
- **Tests use Swift Testing** — use `@Test` with `#expect`/`#require`; add `async` only when the test performs asynchronous work.
- **`RendererRegistry` and `SyntaxHighlightingRegistry`/`Cache` are actors** — interactions require `await`.
- **WebView types require `@MainActor`** — `MarkdownWebView` and `MermaidWebView` in `WebViewSupport.swift` must be used on the main thread.
- **HTML entity decoding is not implemented** — entities like `&amp;` pass through as-is.

## Code Style

- 4 spaces indentation (no tabs), 120 character line limit
- Explicit access control at public and module boundaries
- Test naming: `featureName_condition_expectedResult` (no `test` prefix — `@Test` attribute handles discovery)
- Branch naming: `feature/`, `fix/`, `docs/`, `test/`, `refactor/`
