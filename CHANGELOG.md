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
  - **Built-in Themes**: GitHub, Xcode, VS Code Dark themes with professional styling
  - **Performance Optimized**: Actor-based engine registry with LRU caching
  - **Thread-Safe**: Built with Swift 6 concurrency patterns
  - **Extensible**: Easy to add new languages and custom themes
- **Enhanced HTML Rendering**: Syntax highlighting integration with HTML renderer
  - CSS class generation with configurable prefixes
  - Theme-based color styling
  - Semantic HTML output with proper `<code>` and `<pre>` structure
- **SwiftUI Syntax Highlighting**: Native SwiftUI code block rendering
  - Attributed text with proper color highlighting
  - Monospace font support with custom font configuration
  - Theme integration with SwiftUI color system
- **New Configuration Option**: Added `maxParsingTime` parameter to `SwiftMarkdownParser.Configuration`
  - Configurable timeout for parsing operations (default: 30.0 seconds)
  - Set to 0.0 to disable timeout (use with caution)
  - Provides protection against maliciously crafted documents and infinite loops
- **Enhanced Protection Mechanisms**: Implemented intelligent parser protection systems
  - Time-based protection with configurable timeout
  - Position tracking to detect infinite loops when parser gets stuck
  - Consecutive nil block detection to prevent empty block parsing loops
  - Improved error messages for timeout scenarios
- **Large Document Support**: Added comprehensive test suite for large document parsing
  - Performance testing with real-world documents (README.md as test case)
  - Validation of protection mechanisms under various conditions
  - Concurrent parsing tests to ensure thread safety

### Changed
- **Removed Artificial Block Limits**: Eliminated the hardcoded 100-block limit that was preventing large documents from being fully parsed
  - Parser can now handle documents of any reasonable size
  - Replaced with intelligent protection mechanisms that detect actual problems
  - Improved performance for large technical documentation
- **Enhanced Error Handling**: Added new error type `MarkdownParserError.parsingTimeout`
  - Better error messages for timeout scenarios
  - Improved debugging information for parser issues
- **Updated Documentation**: Comprehensive documentation updates across all guides
  - Added configuration examples for different use cases
  - Performance considerations for various scenarios
  - Security recommendations for user-generated content

### Fixed
- **Large Document Parsing**: Fixed issue where parser would stop at 100 blocks, preventing full document parsing
- **Infinite Loop Protection**: Improved detection and prevention of parser infinite loops
- **Performance**: Better handling of complex documents with many elements

### Security
- **Timeout Protection**: Added configurable timeout protection against malicious documents
- **Resource Management**: Improved memory and CPU usage protection for large documents
- **User Content Safety**: Recommendations for shorter timeouts when processing user-generated content

## [Previous Releases]

### [1.0.0] - Previous Release
- Initial release with CommonMark and GFM support
- HTML and SwiftUI renderers
- Basic parser configuration options
- Comprehensive test suite

---

For more details about these changes, see the updated documentation:
- [Parser Usage Documentation](Docs/ParserUsage.md)
- [HTML Renderer Documentation](Docs/HTMLRenderer.md)
- [SwiftUI Renderer Documentation](Docs/SwiftUIRenderer.md)
- [Syntax Highlighting Documentation](Docs/SyntaxHighlighting.md) 