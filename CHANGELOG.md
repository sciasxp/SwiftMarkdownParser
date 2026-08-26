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
- **SwiftUI Code Blocks**: Basic monospace code block rendering
  - Plain text monospace rendering (no syntax highlighting)
  - Custom font configuration support
  - Accessible code block presentation
  - Theme integration with SwiftUI color system
- **Deterministic Resource Limits**: Added source-length, nesting-depth, and work budgets
  - The same Markdown Source and limits now produce the same result or structured error
  - Wall-clock time no longer changes parser correctness
- **Complete Source Ranges**: Parser-produced nodes now carry half-open start/end ranges
- **Atomic Document Construction**: References, tables, task lists, and inline GFM semantics are resolved before `parse(_:)` returns
- **AST Traversal and Rewriting**: Added lazy contextual preorder traversal and immutable bottom-up document rewriting
  - Rewrites can retain, remove, replace, or expand nodes without revisiting replacements
  - Built-in containers preserve metadata and typed table relationships are validated
  - Custom containers can opt into descendant rewriting with `ASTRewritableNode`
- **Large Document Support**: Added comprehensive test suite for large document parsing
  - Performance testing with real-world documents (README.md as test case)
  - Validation of protection mechanisms under various conditions
  - Concurrent parsing tests to ensure thread safety

### Changed
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
  - WebKit presentation reports success only after required runtimes initialize
- **Source-Breaking Syntax Highlighting Interface**: Replaced the public registry, cache, and engine types with `SyntaxHighlighter`
  - Built-in adapter selection, aliases, validation, fallback, and caching have one owner
  - Unsupported languages and adapter failures preserve plain code output
  - `HTMLSyntaxHighlightingOptions` now controls only enablement and CSS prefix
- **Removed Artificial Block Limits**: Eliminated the hardcoded 100-block limit that was preventing large documents from being fully parsed
  - Parser can now handle documents of any reasonable size
  - Replaced with intelligent protection mechanisms that detect actual problems
  - Improved performance for large technical documentation
- **Updated Documentation**: Comprehensive documentation updates across all guides
  - Added resource-limit examples for different trust boundaries
  - Performance considerations for various scenarios
  - Deterministic resource recommendations for user-generated content

### Fixed
- **Large Document Parsing**: Fixed issue where parser would stop at 100 blocks, preventing full document parsing
- **Infinite Loop Protection**: Improved detection and prevention of parser infinite loops
- **Performance**: Better handling of complex documents with many elements

### Security
- **Resource Management**: Added deterministic source, nesting, and work protection for large or hostile documents
- **User Content Safety**: Resource failures are atomic and never expose a partial document

## [Previous Releases]

### [1.0.0] - Previous Release
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
