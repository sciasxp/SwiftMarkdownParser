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
   - A Swift 6.4+ toolchain
   - An SDK capable of targeting iOS 17.0+ or macOS 14.0+

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

- **Follow Swift conventions**: Follow the Swift API Design Guidelines and match the style of the surrounding code (the project has no linter configuration)
- **Write tests**: All new features should include comprehensive tests
- **Document your code**: Add inline documentation for public interfaces
- **Keep commits atomic**: One logical change per commit
- **Preserve module depth**: Keep policy behind the existing document-level interfaces instead of exposing internal stages or adapters

#### Testing Your Changes

```bash
# Run all tests
swift test

# Run a specific test suite
swift test --filter SyntaxHighlighterTests

# Run with verbose output
swift test --verbose

# Build the package and its example executable
swift build
swift run WebViewTest
```

#### Code Style

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 120 characters maximum
- **Access control**: Explicit access levels (`public`, `internal`, `private`)
- **Naming**:
  - `PascalCase` for types and protocols
  - `lowerCamelCase` for functions, variables, and constants (including `static let`)

Example:
```swift
/// Collects links in stable document order.
///
/// - Parameter document: The complete semantic Markdown document.
/// - Returns: Every link encountered during depth-first traversal.
private func links(in document: AST.DocumentNode) -> [AST.LinkNode] {
    document.depthFirst().compactMap { $0.node as? AST.LinkNode }
}
```

### 5. Commit Your Changes

Write clear, descriptive commit messages:

Stage only the files that belong to the change, then check the staged diff:

```bash
git add Sources/SwiftMarkdownParser Tests/SwiftMarkdownParserTests README.md
git diff --cached --check
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
   - Describe the change, its motivation, and how you tested it

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

````markdown
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
````

## 🎯 Areas for Contribution

### High Priority
- **Performance optimizations**: Tokenizer and parser improvements
- **Dialect compliance**: CommonMark 0.30, GFM, math, and Mermaid edge cases
- **SwiftUI renderer**: Native SwiftUI output format
- **Documentation**: API docs, tutorials, examples
- **Test coverage**: Edge cases, performance tests

### Medium Priority
- **Syntax highlighting**: Code block language support
- **AST transformation rules**: Domain-specific rules built on `depthFirst()` and `rewriting(_:)`
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
import Testing
@testable import SwiftMarkdownParser

struct MarkdownDocumentTests {
    @Test func parse_atxHeading_producesHeadingNode() throws {
        let document = try SwiftMarkdownParser().parse("# Heading")

        #expect(document.children.count == 1)
        #expect(document.children.first is AST.HeadingNode)
    }
}
```

Name tests `featureName_condition_expectedResult` without a `test` prefix; the
`@Test` attribute handles discovery.

### Test Categories
- **Module tests**: Exercise behavior through the module's interface
- **Output tests**: Verify complete Document-to-HTML or Document-to-AnyView behavior
- **Performance tests**: Large document handling
- **Edge case tests**: Malformed input, boundary conditions

### Coverage Goals
- **New behavior**: Cover the public interface, fallback, and important edge cases
- **Bug fixes**: Add a regression that fails before the fix
- **Refactoring**: Preserve behavior at the same or deeper module seam

## 📝 Documentation

### Public Interface Documentation
- Use Swift's documentation comments (`///`)
- Include parameter descriptions and return values
- Provide usage examples for complex APIs
- Document throwing behavior and error conditions

### README Updates
- Keep examples current and working
- Update feature lists when adding capabilities
- Maintain accurate installation instructions
- Update `Docs/Architecture.md` when module ownership or a public seam changes

### Code Examples
```swift
/// Example of parsing a complex markdown document
///
/// ```swift
/// let parser = SwiftMarkdownParser()
/// let document = try parser.parse(complexMarkdown)
/// let html = try await HTMLRenderer().renderFragment(document)
/// ```
```

## 🔄 Review Process

### What to Expect
1. **Automated checks**: CI builds the package and runs the test suite
2. **Code review**: Maintainer review for code quality and design
3. **Feedback**: Constructive feedback and suggestions
4. **Iteration**: You may need to make changes based on feedback

### Review Criteria
- **Functionality**: Does it work as intended?
- **Tests**: Are there adequate tests?
- **Documentation**: Is it properly documented?
- **Performance**: Does it maintain or improve performance?
- **Interface design**: Does it preserve depth, locality, and existing seams?
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
- [ ] Git tag created (Swift Package Manager versions come from tags, not from Package.swift)
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
- **Credited in Git history**: Your commits carry your authorship
- **Mentioned in release notes**: Significant contributions highlighted
- **Invited as collaborators**: Regular contributors may be invited as maintainers

## 📄 License

By contributing to SwiftMarkdownParser, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to SwiftMarkdownParser! Your efforts help make markdown parsing better for the entire Swift community. 🚀
