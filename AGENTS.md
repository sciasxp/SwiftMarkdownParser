# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Cursor, etc.) working in this repository. Single source of agent instructions — there is no `CLAUDE.md`.

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

**HTML output seam:** `HTMLRenderer` owns HTML escaping, GFM, syntax highlighting, Mermaid, KaTeX, CSS, scripts, and complete-document composition. Configure it with `HTMLRenderOptions`; callers render only complete `DocumentNode` values. `BrowserDocumentAssembler` discovers runtime requirements during body rendering, deduplicates assets, and emits one readiness/failure bootstrap. Configuration values stay data-only.

**Syntax-highlighting seam:** `SyntaxHighlighter` accepts code plus a language identifier and returns optional semantic tokens. It owns built-in adapter selection, aliases, support discovery, token validation, best-effort fallback, and bounded LRU caching. The six `*SyntaxEngine` adapters and cache representation are internal; `HTMLCodeBlockRenderer` owns only safe token-to-HTML presentation.

**SwiftUI output seam:** `SwiftUIRenderer` is `@MainActor`, accepts `SwiftUIRenderOptions`, and produces `AnyView` from a complete `DocumentNode`. `MarkdownWebView` is an HTML presentation adapter and also accepts a document rather than Markdown source.

## Key Source Directories

- `Sources/SwiftMarkdownParser/` — all library code
  - Construction: `Parsing/SwiftMarkdownParser.swift`, `Tokenizer.swift`, `BlockParser.swift`, `InlineParser.swift`
  - AST: `AST.swift`, `ASTTraversal.swift`, `ASTRewriter.swift`
  - HTML output: `Rendering/HTML/`
  - Native SwiftUI output: `Rendering/SwiftUI/`
  - GFM table utilities: `GFMExtensions.swift`
  - Syntax highlighting: `SyntaxHighlighter.swift`, public semantic types in `SyntaxHighlighting.swift`, and one internal `*SyntaxEngine.swift` adapter per language
- `Tests/SwiftMarkdownParserTests/` — Swift Testing suites and repository-owned fixtures
- `Examples/` — `WebViewTest.swift`, `AST_Example.swift`
- `Docs/` — usage guides for HTML rendering, SwiftUI rendering, syntax highlighting, Mermaid, KaTeX

## Gotchas

- **Document construction is synchronous** — call `try parser.parse(source)`; renderer operations remain `async throws`.
- **AST rewriting is bottom-up and one-shot** — a visit observes rewritten descendants, while replacement nodes are not revisited in the same pass.
- **Test at document-level seams** — construction tests use Source → Document; output tests use Document → HTML/AnyView. Direct token or node-render tests are reserved for internal invariants.
- **Tests use Swift Testing** — use `@Test` with `#expect`/`#require`; add `async` only when the test performs asynchronous work.
- **Syntax support has one source of truth** — ask `await SyntaxHighlighter.supportedLanguages`; HTML options only enable highlighting and choose the CSS prefix.
- **SwiftUI output requires `@MainActor`** — create and call `SwiftUIRenderer` and `MarkdownWebView` on the main actor.
- **Bundled browser assets are real package resources** — `.bundled` inlines pinned Mermaid 10.9.1 or KaTeX 0.16.21 assets; `.cdn` keeps documents small, and `.custom` accepts validated HTTPS or file URLs.
- **Browser readiness is semantic** — `MarkdownWebView.onRender` succeeds after required runtimes initialize, not merely after WebKit navigation finishes.
- **HTML entity decoding is not implemented** — entities like `&amp;` pass through as-is.

## Code Style

- 4 spaces indentation (no tabs), 120 character line limit
- Explicit access control at public and module boundaries
- Test naming: `featureName_condition_expectedResult` (no `test` prefix — `@Test` attribute handles discovery)
- Branch naming: `feature/`, `fix/`, `docs/`, `test/`, `refactor/`
