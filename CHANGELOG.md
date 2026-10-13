# Changelog

All notable changes to SwiftMarkdownParser will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **🎨 Professional Syntax Highlighting**: Complete syntax highlighting system for code blocks
  - **6 Programming Languages**: JavaScript, TypeScript, Swift, Kotlin, Python, Bash
  - **25+ Token Types**: Keywords, strings, comments, operators, types, functions, and more
  - **Modern Language Features**: ES6+, async/await, generics, coroutines, decorators
  - **Built-in Themes**: GitHub, Xcode, and VS Code Dark semantic color palettes
  - **Performance Optimized**: Actor-isolated orchestration with bounded LRU caching
  - **Thread-Safe**: Built with Swift 6 concurrency patterns
  - **Truthful Discovery**: Supported identifiers and aliases come from built-in adapters
- **Enhanced HTML Rendering**: Syntax highlighting integration with HTML renderer
  - CSS class generation with configurable prefixes
  - Caller-defined color styling through semantic token classes
  - Semantic HTML output with proper `<code>` and `<pre>` structure
- **SwiftUI Code Blocks**: Native code rendering with opt-in semantic highlighting
  - Complete-source fallback for unlabelled, unsupported, or failed highlighting
  - Custom font configuration support
  - Accessible code block presentation
  - GitHub, Xcode, VS Code Dark, and custom theme integration
- **SwiftUI Rendering Coverage**: Completed native document behavior at the public renderer seam
  - Wrapping formatted links with host-controlled URL routing and relative URL resolution
  - Default `AsyncImage` rendering plus custom image loading
  - Ordered-list start numbers, footnotes, static task semantics, and formatted table cells
  - Explicit host adapters with readable source fallbacks for Mermaid, math, and raw HTML
- **Deterministic Resource Limits**: Added source-length, nesting-depth, and work budgets
  - The same Markdown Source and limits now produce the same result or structured error
  - Wall-clock time no longer changes parser correctness
- **Complete Source Ranges**: Parser-produced nodes now carry half-open start/end ranges
- **Atomic Document Construction**: References, tables, task lists, and inline GFM semantics are resolved before `parse(_:)` returns
- **Typed Mermaid Theme Variables**: `MermaidConfiguration.ThemeVariables` carries caller-owned palettes as inert configuration data
- **Replaceable Document Styling**: `HTMLRenderOptions.includeDefaultStyles` lets host presentations own visual CSS while the renderer retains document and runtime assembly
- **AST Traversal and Rewriting**: Added lazy contextual preorder traversal and immutable bottom-up document rewriting
  - Rewrites can retain, remove, replace, or expand nodes without revisiting replacements
  - Built-in containers preserve metadata and typed table relationships are validated
  - Custom containers can opt into descendant rewriting with `ASTRewritableNode`
- **Large Document Support**: Added comprehensive test suite for large document parsing
  - Performance testing with real-world documents (README.md as test case)
  - Validation of protection mechanisms under various conditions
  - Concurrent parsing tests to ensure thread safety
- **Localized Native Semantics**: SwiftUI fallback titles, renderer errors, and VoiceOver labels ship in English and Brazilian Portuguese (pt-BR) ([ADR 0008](Docs/adr/0008-concentrate-native-semantics-and-localization.md))

### Changed
- **Inline Fragment Work**: Setext heading text and inline-parsed table cells charge one extra unit of work per character to `ResourceLimits.maximumWork`, for their fragment's line table (ADR 0014)
- **Unicode Separators Are Whitespace**: U+2028, U+2029, NEL, VT, and FF no longer end a line; they are whitespace inside it, as CommonMark specifies (ADR 0014)
- **Source-Breaking Parser Interface**: Replaced async `parseToAST(_:)` and mode-based `Configuration` with synchronous `parse(_:)` and `ResourceLimits`
  - The Supported Dialect is fixed to CommonMark 0.30, GFM, math, and Mermaid
  - Tokenizer, token stream, block parser, inline parser, and grammar utilities are internal
  - Parser failures use the single `MarkdownParsingError` family
- **Output-Specific Renderers**: Removed the shared renderer protocol and split source layout by output
  - HTML owns escaping, GFM output, browser enrichment, and document composition
  - SwiftUI owns main-actor native view construction
  - Both renderers accept only complete `AST.DocumentNode` values
- **Browser Enrichment Assembly**: HTML rendering discovers required browser behavior before assembling resources
  - Mermaid, KaTeX, footnote, and task-list requirements are deduplicated centrally
  - Bundled Mermaid and KaTeX resources support deterministic offline output
  - Versioned runtime observations report required and failed features exactly once
  - WebKit presentation reports success only after required runtimes initialize while preserving its public callback
  - `HTMLDocumentAssembly` places host styles, scripts, and addressable regions during the same complete-document assembly
- **Source-Breaking Syntax Highlighting Interface**: Replaced the public registry, cache, and engine types with `SyntaxHighlighter`
  - Built-in adapter selection, aliases, validation, fallback, and caching have one owner
  - Unsupported languages and adapter failures preserve plain code output
  - `HTMLSyntaxHighlightingOptions` now controls only enablement and CSS prefix
- **Native SwiftUI Rendering Internals**: Deepened the internal native presentation modules; the public `SwiftUIRenderer` interface is unchanged
  - Adaptive, Dynamic Type-aware block layout in one module ([ADR 0006](Docs/adr/0006-deepen-native-adaptive-presentation.md))
  - One closed `SwiftUIRichContentRequest` / `SwiftUIRichContentAdapter` seam with native fallbacks ([ADR 0007](Docs/adr/0007-deepen-native-rich-content-seam.md))
  - Main-actor view identity and materialization ([ADR 0009](Docs/adr/0009-own-native-identity-and-materialization.md))
  - Atomic document projection: a complete typed plan is built before any view is materialized ([ADR 0010](Docs/adr/0010-plan-native-documents-before-materialization.md))
  - Shared adaptive label/content presentation for list markers, tasks, footnotes, Mermaid titles, and table fields ([ADR 0011](Docs/adr/0011-deepen-adaptive-label-content-presentation.md))
  - Table meaning (columns, alignment, headers) normalized once in the projection ([ADR 0012](Docs/adr/0012-normalize-native-table-meaning-once.md))
  - `NativePresentationStyle` normalizes `SwiftUIStyleConfiguration` metrics once and shares role values across modules ([ADR 0013](Docs/adr/0013-deepen-native-presentation-style.md))
- **Removed Artificial Block Limits**: Eliminated the hardcoded 100-block limit that was preventing large documents from being fully parsed
  - Parser can now handle documents of any reasonable size
  - Replaced with intelligent protection mechanisms that detect actual problems
  - Improved performance for large technical documentation
- **Updated Documentation**: Guides realigned with the current public API
  - Fixed non-compiling examples and the Swift Package Manager install snippet
  - Documented `NativePresentationStyle`, renderer error types, Mermaid layout configuration, and style variants
  - Completed the AST node list and syntax-highlighting token table; corrected theme color values and source-tree layouts

### Fixed
- **Line Endings**: Construction recognizes exactly the CommonMark line endings (LF, CR, CRLF) in one place, so blocks separate and tokens, references, tables, and document ranges agree on line numbers; `SourceLocation.extending(over:)` now starts a new line at CR and CRLF
- **Large Document Parsing**: Fixed issue where parser would stop at 100 blocks, preventing full document parsing
- **Infinite Loop Protection**: Improved detection and prevention of parser infinite loops
- **Performance**: Better handling of complex documents with many elements

### Security
- **Resource Management**: Added deterministic source, nesting, and work protection for large or hostile documents
- **User Content Safety**: Resource failures are atomic and never expose a partial document

## [Previous Releases]

### [1.0.0]
- Initial release with CommonMark and GFM support
- HTML and SwiftUI renderers
- Basic parser configuration options
- Comprehensive test suite

---

For more details about these changes, see the updated documentation:
- [Architecture Documentation](Docs/Architecture.md)
- [Parser Usage Documentation](Docs/ParserUsage.md)
- [HTML Renderer Documentation](Docs/HTMLRenderer.md)
- [SwiftUI Renderer Documentation](Docs/SwiftUIRenderer.md)
- [Syntax Highlighting Documentation](Docs/SyntaxHighlighting.md)
