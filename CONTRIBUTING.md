# Contributing to SwiftMarkdownParser

Thank you for your interest in contributing to SwiftMarkdownParser! We welcome contributions from the community and are excited to see what you'll bring to the project.

## 🤝 How to Contribute

### 1. Fork the Repository

1. **Fork the project** on GitHub by clicking the "Fork" button in the top-right corner
2. **Clone your fork** to your local machine:
   ```bash
   git clone https://github.com/YOUR_USERNAME/SwiftMarkdownParser.git
   cd SwiftMarkdownParser
   ```
3. **Add the original repository** as a remote:
   ```bash
   git remote add upstream https://github.com/sciasxp/SwiftMarkdownParser.git
   ```

### 2. Set Up Development Environment

1. **Requirements**:
   - Xcode 16.0+ with Swift 6.0+
   - iOS 18.0+ / macOS 15.0+ SDK

2. **Verify setup**:
   ```bash
   swift --version
   swift test
   ```

3. **Open in Xcode** (optional):
   ```bash
   open Package.swift
   ```

### 3. Create a Feature Branch

Always create a new branch for your changes:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
# or  
git checkout -b docs/documentation-update
```

**Branch naming conventions**:
- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `test/` - Test improvements
- `refactor/` - Code refactoring

### 4. Make Your Changes

#### Code Guidelines

- **Follow Swift conventions**: Use SwiftLint rules and Swift API Design Guidelines
- **Write tests**: All new features should include comprehensive tests
- **Document your code**: Add inline documentation for public APIs
- **Keep commits atomic**: One logical change per commit

#### Testing Your Changes

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter SwiftMarkdownParserTests

# Run with verbose output
swift test --verbose

# Test on different platforms (if available)
swift test --destination platform=iOS
swift test --destination platform=macOS
```

#### Code Style

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 120 characters maximum
- **Access control**: Explicit access levels (`public`, `internal`, `private`)
- **Naming**: 
  - `PascalCase` for types and protocols
  - `camelCase` for functions and variables
  - `UPPER_CASE` for constants

Example:
```swift
/// Parse a GFM table from markdown tokens
/// 
/// - Parameter tokens: The token stream to parse
/// - Returns: A GFMTableNode or nil if parsing fails
/// - Throws: MarkdownParsingError if the table structure is invalid
public func parseGFMTable(_ tokens: TokenStream) throws -> AST.GFMTableNode? {
    // Implementation here
}
```

### 5. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "Add support for GFM table alignment

- Implement left, center, right alignment parsing
- Add alignment property to GFMTableCellNode  
- Update HTML renderer to output alignment styles
- Add comprehensive tests for all alignment types

Fixes #123"
```

**Commit message format**:
- **First line**: Brief description (50 chars max)
- **Blank line**
- **Body**: Detailed explanation of what and why
- **Footer**: Reference issues with "Fixes #123" or "Closes #123"

### 6. Push and Create Pull Request

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request** on GitHub:
   - Go to your fork on GitHub
   - Click "Compare & pull request"
   - Fill out the PR template with details

3. **PR Guidelines**:
   - **Clear title**: Describe what the PR does
   - **Detailed description**: Explain the changes and reasoning
   - **Link issues**: Reference related issues with "Fixes #123"
   - **Screenshots**: Include screenshots for UI changes
   - **Breaking changes**: Clearly mark any breaking changes

## 🐛 Reporting Issues

### Before Reporting

1. **Search existing issues** to avoid duplicates
2. **Test with latest version** to ensure the issue still exists
3. **Minimal reproduction**: Create the smallest possible example

### Issue Template

```markdown
**Description**
A clear description of the issue.

**Expected Behavior**
What you expected to happen.

**Actual Behavior**  
What actually happened.

**Minimal Reproduction**
```swift
let markdown = "..."
let parser = SwiftMarkdownParser()
// Steps to reproduce
```

**Environment**
- iOS/macOS version:
- Xcode version:
- Swift version:
- SwiftMarkdownParser version:

**Additional Context**
Any other relevant information.
```

## 🎯 Areas for Contribution

### High Priority
- **Performance optimizations**: Tokenizer and parser improvements
- **GFM extensions**: Math support, footnotes, definition lists
- **SwiftUI renderer**: Native SwiftUI output format
- **Documentation**: API docs, tutorials, examples
- **Test coverage**: Edge cases, performance tests

### Medium Priority
- **Syntax highlighting**: Code block language support
- **Custom extensions**: Plugin system for custom markdown elements
- **Error handling**: Better error messages and recovery
- **Accessibility**: VoiceOver and accessibility improvements

### Good First Issues
- **Documentation fixes**: Typos, clarifications, examples
- **Test additions**: Missing test cases, edge cases
- **Code cleanup**: Refactoring, code organization
- **Example projects**: Sample apps demonstrating usage

## 🧪 Testing Guidelines

### Test Structure
```swift
func test_featureName_condition_expectedResult() async throws {
    // Arrange
    let markdown = "..."
    let parser = SwiftMarkdownParser()
    
    // Act
    let ast = try await parser.parseToAST(markdown)
    
    // Assert
    XCTAssertEqual(ast.children.count, 1)
    XCTAssertTrue(ast.children.first is AST.ParagraphNode)
}
```

### Test Categories
- **Unit tests**: Individual components and functions
- **Integration tests**: End-to-end parsing and rendering
- **Performance tests**: Large document handling
- **Edge case tests**: Malformed input, boundary conditions

### Coverage Goals
- **New features**: 100% test coverage
- **Bug fixes**: Test that reproduces the bug + fix verification
- **Refactoring**: Maintain existing test coverage

## 📝 Documentation

### API Documentation
- Use Swift's documentation comments (`///`)
- Include parameter descriptions and return values
- Provide usage examples for complex APIs
- Document throwing behavior and error conditions

### README Updates
- Keep examples current and working
- Update feature lists when adding capabilities
- Maintain accurate installation instructions

### Code Examples
```swift
/// Example of parsing a complex markdown document
/// 
/// ```swift
/// let parser = SwiftMarkdownParser()
/// let ast = try await parser.parseToAST(complexMarkdown)
/// let html = try await parser.parseToHTML(complexMarkdown)
/// ```
```

## 🔄 Review Process

### What to Expect
1. **Automated checks**: Tests, linting, and build verification
2. **Code review**: Maintainer review for code quality and design
3. **Feedback**: Constructive feedback and suggestions
4. **Iteration**: You may need to make changes based on feedback

### Review Criteria
- **Functionality**: Does it work as intended?
- **Tests**: Are there adequate tests?
- **Documentation**: Is it properly documented?
- **Performance**: Does it maintain or improve performance?
- **API design**: Is it consistent with existing APIs?
- **Breaking changes**: Are they necessary and well-documented?

## 📋 Release Process

### Versioning
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist
- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in Package.swift
- [ ] Git tag created
- [ ] GitHub release created

## 🙋 Getting Help

### Communication Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community discussion
- **Pull Request Comments**: Code-specific questions

### Maintainer Response Time
- **Issues**: We aim to respond within 48 hours
- **Pull Requests**: Initial review within 72 hours
- **Questions**: Community discussions within 24 hours

## 🎉 Recognition

Contributors will be:
- **Listed in CONTRIBUTORS.md**: All contributors are recognized
- **Mentioned in release notes**: Significant contributions highlighted
- **Invited as collaborators**: Regular contributors may be invited as maintainers

## 📄 License

By contributing to SwiftMarkdownParser, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to SwiftMarkdownParser! Your efforts help make markdown parsing better for the entire Swift community. 🚀
