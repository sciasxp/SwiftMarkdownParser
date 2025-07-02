# Swift Markdown Parser

A lightweight, Swift-native library for parsing Markdown documents into structured data.

## Features

- **Swift 6 Compatible**: Built with the latest Swift language features
- **iOS 18+ & macOS 15+**: Supports the latest Apple platforms
- **Structured Output**: Converts Markdown to structured Swift types
- **Error Handling**: Comprehensive error reporting for parsing issues
- **Lightweight**: Minimal dependencies and fast performance

## Requirements

- iOS 18.0+
- macOS 15.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftMarkdownParser.git", from: "1.0.0")
]
```

Or add it through Xcode:

1. Go to File → Add Package Dependencies
2. Enter the repository URL
3. Select your desired version

## Usage

### Basic Usage

```swift
import SwiftMarkdownParser

let parser = SwiftMarkdownParser()
let markdown = """
# Hello World

This is a **bold** paragraph with some *italic* text.

## Subheading

- List item 1
- List item 2
- List item 3
"""

do {
    let document = try parser.parse(markdown)
    print("Parsed \(document.elements.count) elements")
} catch {
    print("Parsing failed: \(error)")
}
```

### Working with Parsed Elements

```swift
let document = try parser.parse(markdown)

for element in document.elements {
    switch element {
    case .heading(let level, let text):
        print("Heading \(level): \(text)")
    case .paragraph(let text):
        print("Paragraph: \(text)")
    case .list(let items, let isOrdered):
        print("\(isOrdered ? "Ordered" : "Unordered") list with \(items.count) items")
    case .codeBlock(let language, let code):
        print("Code block (\(language ?? "plain")): \(code)")
    case .blockquote(let text):
        print("Quote: \(text)")
    case .horizontalRule:
        print("Horizontal rule")
    }
}
```

## Supported Markdown Elements

- **Headings**: `# H1`, `## H2`, etc.
- **Paragraphs**: Regular text blocks
- **Lists**: Both ordered and unordered
- **Code blocks**: Fenced code blocks with optional language
- **Blockquotes**: `> quoted text`
- **Horizontal rules**: `---` or `***`

## Error Handling

The parser provides detailed error information through the `MarkdownParseError` enum:

```swift
do {
    let document = try parser.parse(invalidMarkdown)
} catch MarkdownParseError.invalidInput {
    print("Invalid input provided")
} catch MarkdownParseError.unsupportedElement(let element) {
    print("Unsupported element: \(element)")
} catch MarkdownParseError.parsingFailed(let reason) {
    print("Parsing failed: \(reason)")
}
```

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Linting

```bash
swift-format --in-place --recursive Sources/ Tests/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Roadmap

- [ ] Support for inline formatting (bold, italic, code)
- [ ] Table parsing
- [ ] Link and image parsing
- [ ] Custom element extensions
- [ ] HTML output rendering
- [ ] Performance optimizations

## Support

For questions, issues, or contributions, please visit the [GitHub repository](https://github.com/yourusername/SwiftMarkdownParser). 