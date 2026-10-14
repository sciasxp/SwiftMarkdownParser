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
- **Destination Allowlist**: Link, image, and autolink destinations are decided once by `MarkdownDestination` for HTML and SwiftUI output ([ADR 0015](Docs/adr/0015-own-destination-safety-and-resolution.md))
  - Only `http`, `https`, `mailto`, relative references, and fragments are kept; `vbscript:`, `ftp:`, explicit `file:`, and every other scheme now render as the link text, image alt text, or autolink text
  - An empty destination, such as `[x]()`, keeps CommonMark's `href=""`; with a `baseURL` it resolves to the base without its fragment, in HTML and SwiftUI output
  - A `file:` URL produced by resolving a relative destination against a host `file:` base URL is still accepted, unless the destination starts with `//` without being exactly `///` followed by a path segment; four or more slashes (`////evil.com/share`) are refused
  - A protocol-relative destination (`//host/x`) is resolved only against an `http` or `https` base URL, where it takes the base's scheme; without a base URL it renders as text
  - HTML resolves relative destinations with Foundation whenever `baseURL` is set and emits the percent-encoded result (`my page.html` becomes `my%20page.html`)
- **Paragraph Continuation**: Consecutive lines now form one paragraph, as CommonMark 0.30 section 4.8 specifies, instead of one paragraph per line; this is an intentional behavior change ([ADR 0016](Docs/adr/0016-recognize-link-reference-definitions-in-the-block-phase.md))
  - Lazy continuation lines extend a paragraph inside a block quote or list item; a blank line or a block that can interrupt a paragraph (heading, fence, thematic break, block quote, list item, HTML block, `$$` block, table) ends it
  - Line endings inside a paragraph are `SoftBreakNode`s; two trailing spaces or a backslash make a hard `LineBreakNode`
  - Code spans and strikethrough cross lines inside their paragraph; a code span turns line endings into spaces
  - Setext headings can span lines, and a setext underline may be a single `=` or `-`
  - A list item's marker line starts any block (`- # foo` is a heading, a fence there is a code block without the item's indentation); `* * *` is a thematic break, not nested empty items, on an item's marker line, on its continuation lines, and after it; an HTML block ends with its list item; an empty item ends at a blank line
  - A fence or `$$` math block ends with the list item or block quote that holds it, takes no lazy lines, and never takes container markers as code or math; a list inside a block quote continues on the quote's marked lines
  - A blank line ends a block quote, with any fence or `$$` math block open in it: `> foo`, a blank line, and `> bar` are two quotes
  - A backslash with nothing after it is literal
  - Of the 652 CommonMark 0.30 examples, 169 change their HTML with this entry and the Link Reference Definitions entry below; under whitespace normalization the passing examples go from 212 to 298 with this entry alone (with fences ending with their containers) and to 316 with the Link Reference Definitions entry, and none that passed fails
- **Block and Inline Phases**: Document construction recognizes all blocks before it interprets any inline text (ADR 0016)
  - Paragraph and heading text is tokenized again as its own inline fragment, so it charges more work to `ResourceLimits.maximumWork`: a document with a heading, a paragraph, and two list items costs 565 units instead of 420
  - The cost stays linear; the worst case measured is about 2x the previous cost (a single very long line, or a long list), and ordinary prose costs 6 to 7.5 units per character, so 2,000,000 characters of prose still fit the default limit; dense lists cost about 14 units per character, so a list above about 1,800,000 characters no longer fits the default `maximumWork`, which is unchanged
  - Finding the line that closes a fence or a `$$` math block charges one unit per scanned line, so `maximumWork` bounds it; a fence of 2,000 lines costs 2,001 units more. Repeated unclosed `$$` lines no longer rescan the rest of the document, which made them quadratic: 20,000 of them took about 94 s and now parse in linear time
- **Link Reference Definitions in the Block Phase**: Definitions are recognized when a paragraph closes, as CommonMark 0.30 section 4.7 specifies, instead of by a line-based pre-read; this is an intentional behavior change (ADR 0016)
  - A definition inside a block quote or list item applies to the whole document; labels, destinations, and titles may continue on the following lines; backslash escapes are decoded in destinations and titles
  - A definition cannot interrupt a paragraph: `text` followed by `[a]: url` stays one paragraph
  - A definition inside a `$$` math block or an HTML block stays content
  - A line that is not a complete definition, such as `[^1]: The note.` or `[foo]: /url "title" ok`, is now paragraph text instead of being consumed
  - Under whitespace normalization the passing CommonMark 0.30 examples go from 298 to 315, and to 316 once a blank line ends a block quote; none that passed fails
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
- **Destination Scheme Bypass**: A TAB, LF, or CR inside a destination's scheme (for example `java<TAB>script:alert(1)` in a reference definition) no longer reaches `href` or `src`; destinations are normalized the way browsers parse URLs before the scheme is checked
- **Destination Scheme Bypass Through Combining Characters**: A combining mark, ZWJ, ZWNJ, or variation selector right after the scheme's colon (for example `javascript:\u{301}alert(1)` in a reference definition with a `baseURL`) no longer reaches `href` or `src`; the scheme is read by Unicode scalar and the resolved URL's scheme is checked against the allowlist again
- **Protocol-Relative File Shares**: A protocol-relative destination resolved against a `file:` base URL (for example `[x](//evil.com/share)` or `[x](//:80/x)` with `file:///docs/`) renders as text instead of linking to the network share `file://evil.com/share` or `file://:80/x`; four or more slashes (`[x](////evil.com/share)`, which Windows browsers read as the UNC share `\\evil.com\share`) also render as text
- **Protocol-Relative Destinations Without a Base URL**: `![x](//evil.com/a.png)` without a `baseURL` renders its alt text instead of `<img src="//evil.com/a.png">`, which browsers load from `evil.com`; this also covers links, autolinks, SwiftUI output, and leading NBSP, ZWSP, U+3000, U+2028, C0 controls, or `/<TAB>/` that normalization joins into `//`
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
