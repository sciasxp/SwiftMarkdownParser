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
    ├→ HTMLRenderer.renderFragment(_:) / renderDocument(_:metadata:)
    └→ SwiftUIRenderer.render(_:)
```

**Construction seam:** `SwiftMarkdownParser` exposes synchronous `parse(_:)` and deterministic `ResourceLimits`. Token, block, and inline parsers are internal implementation details. The supported dialect is fixed to CommonMark 0.30, GFM, math, and Mermaid.

**AST operations:** `depthFirst()` in `ASTTraversal.swift` is the shared lazy preorder seam for generic scans. `DocumentNode.rewriting(_:)` in `ASTRewriter.swift` is a bottom-up, one-shot immutable rewrite; built-in metadata is preserved, and custom containers adopt `ASTRewritableNode` to support rewritten descendants.

**HTML output seam:** `HTMLRenderer` owns HTML escaping, GFM, syntax highlighting, Mermaid, KaTeX, CSS, scripts, and complete-document composition. Configure it with `HTMLRenderOptions`; callers render only complete `DocumentNode` values.

**SwiftUI output seam:** `SwiftUIRenderer` is `@MainActor`, accepts `SwiftUIRenderOptions`, and produces `AnyView` from a complete `DocumentNode`. `MarkdownWebView` is an HTML presentation adapter and also accepts a document rather than Markdown source.

## Key Source Directories

- `Sources/SwiftMarkdownParser/` — all library code
  - Construction: `Parsing/SwiftMarkdownParser.swift`, `Tokenizer.swift`, `BlockParser.swift`, `InlineParser.swift`
  - AST: `AST.swift`, `ASTTraversal.swift`, `ASTRewriter.swift`
  - HTML output: `Rendering/HTML/`
  - Native SwiftUI output: `Rendering/SwiftUI/`
  - GFM table utilities: `GFMExtensions.swift`
  - Syntax highlighting: `SyntaxHighlighting.swift` + one `*SyntaxEngine.swift` per language (JS, TS, Swift, Kotlin, Python, Bash)
- `Tests/SwiftMarkdownParserTests/` — Swift Testing suites and repository-owned fixtures
- `Examples/` — `WebViewTest.swift`, `AST_Example.swift`
- `Docs/` — usage guides for HTML rendering, SwiftUI rendering, syntax highlighting, Mermaid, KaTeX

## Gotchas

- **Document construction is synchronous** — call `try parser.parse(source)`; renderer operations remain `async throws`.
- **AST rewriting is bottom-up and one-shot** — a visit observes rewritten descendants, while replacement nodes are not revisited in the same pass.
- **Test at document-level seams** — construction tests use Source → Document; output tests use Document → HTML/AnyView. Direct token or node-render tests are reserved for internal invariants.
- **Tests use Swift Testing** — use `@Test` with `#expect`/`#require`; add `async` only when the test performs asynchronous work.
- **`SyntaxHighlightingRegistry`/`Cache` are actors** — interactions require `await`.
- **SwiftUI output requires `@MainActor`** — create and call `SwiftUIRenderer` and `MarkdownWebView` on the main actor.
- **HTML entity decoding is not implemented** — entities like `&amp;` pass through as-is.

## Code Style

- 4 spaces indentation (no tabs), 120 character line limit
- Explicit access control at public and module boundaries
- Test naming: `featureName_condition_expectedResult` (no `test` prefix — `@Test` attribute handles discovery)
- Branch naming: `feature/`, `fix/`, `docs/`, `test/`, `refactor/`
