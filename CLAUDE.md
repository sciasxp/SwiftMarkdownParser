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

## Architecture: Parsing Pipeline

```
Markdown String
    → MarkdownTokenizer        (Tokenizer.swift — lexes into 31 token types)
    → TokenStream              (Tokenizer.swift — manages consumption/lookahead)
    → BlockParser              (BlockParser.swift — builds block-level AST)
    → InlineParser             (InlineParser.swift — parses inline content within blocks)
    → Post-processing          (SwiftMarkdownParser.swift — GFM strikethrough, autolinks)
    → AST (DocumentNode)       (AST.swift — 30+ node types)
    → Renderer                 (HTMLRenderer in SwiftMarkdownParser.swift, or SwiftUIRenderer)
```

**Entry point:** `SwiftMarkdownParser` class in `SwiftMarkdownParser.swift` — exposes `parseToAST()`, `parseToHTML()`, and themed HTML variants. The `HTMLRenderer` struct is also defined in this file.

**Renderer protocol:** `MarkdownRenderer` in `RendererProtocol.swift` — generic over `Output` and `Context` types. `RendererRegistry` (actor) manages multiple renderers. GFM table/task-list rendering is implemented as extensions on this protocol.

**SwiftUI rendering:** `SwiftUIRenderer` in `SwiftUIRenderer.swift` and `SwiftUIRenderContext` in `SwiftUIRenderContext.swift` — produces `AnyView` output, requires iOS 17.0+/macOS 14.0+.

## Key Source Directories

- `Sources/SwiftMarkdownParser/` — all library code (22 files)
  - Core parser: `SwiftMarkdownParser.swift`, `Tokenizer.swift`, `BlockParser.swift`, `InlineParser.swift`, `AST.swift`
  - Renderers: `RendererProtocol.swift`, `SwiftUIRenderer.swift`, `SwiftUIRenderContext.swift`, `MermaidRenderer.swift`, `MermaidConfiguration.swift`, `KaTeXRenderer.swift`, `KaTeXConfiguration.swift`, `WebViewSupport.swift`
  - GFM/CommonMark utils: `GFMExtensions.swift`, `CommonMarkExtensions.swift`
  - Syntax highlighting: `SyntaxHighlighting.swift` + one `*SyntaxEngine.swift` per language (JS, TS, Swift, Kotlin, Python, Bash)
- `Tests/SwiftMarkdownParserTests/` — 21 test files (Swift Testing framework)
- `Examples/` — `WebViewTest.swift`, `AST_Example.swift`
- `Docs/` — usage guides for HTML rendering, SwiftUI rendering, syntax highlighting, Mermaid, KaTeX

## Gotchas

- **All parsing APIs are `async throws`** — `parseToAST()`, `parseToHTML()`, and renderer methods all require `try await`.
- **Tests use Swift Testing** — new test methods must use `@Test func name() async throws` with `#expect`/`#require` assertions.
- **`RendererRegistry` and `SyntaxHighlightingRegistry`/`Cache` are actors** — interactions require `await`.
- **WebView types require `@MainActor`** — `MarkdownWebView` and `MermaidWebView` in `WebViewSupport.swift` must be used on the main thread.
- **HTML entity decoding is not implemented** — entities like `&amp;` pass through as-is (`InlineParser.swift:638`).

## Code Style

- 4 spaces indentation (no tabs), 120 character line limit
- Explicit access control on all declarations
- Test naming: `featureName_condition_expectedResult` (no `test` prefix — `@Test` attribute handles discovery)
- Branch naming: `feature/`, `fix/`, `docs/`, `test/`, `refactor/`
