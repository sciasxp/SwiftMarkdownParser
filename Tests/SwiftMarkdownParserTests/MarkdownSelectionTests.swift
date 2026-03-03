import Testing
@testable import SwiftMarkdownParser

/// Test suite for specific markdown selection content
/// Tests parsing of numbered lists with bold text and code blocks
@Suite struct MarkdownSelectionTests {

    let parser: SwiftMarkdownParser

    init() {
        // Enable GFM extensions and source location tracking for comprehensive testing
        let config = SwiftMarkdownParser.Configuration(
            enableGFMExtensions: true,
            strictMode: false,
            trackSourceLocations: true
        )
        parser = SwiftMarkdownParser(configuration: config)
    }

    /// Test the parsing of the GitHub instructions markdown selection
    /// This tests a complex structure with numbered lists, bold text, and code blocks
    @Test func parseGitHubInstructionsMarkdown() async throws {
        let markdown = """
        1. **Fork the repository** on GitHub
        2. **Clone your fork**:
           ```bash
           git clone https://github.com/YOUR_USERNAME/SwiftMarkdownParser.git
           cd SwiftMarkdownParser
           ```
        3. **Create a feature branch**:
           ```bash
           git checkout -b feature/your-feature-name
           ```
        """

        let document = try await parser.parseToAST(markdown)

        // Basic validation
        #expect(document != nil, "Document should be parsed successfully")
        #expect(document.children.count == 1, "Document should have one child (the ordered list)")

        // Should have one ordered list
        let list = try #require(document.children.first as? AST.ListNode, "Expected ListNode, got \(type(of: document.children.first))")

        #expect(list.isOrdered, "List should be ordered (numbered)")
        #expect(list.items.count == 3, "List should have 3 items")

        // Test first item: should contain "Fork the repository"
        let firstItem = list.items[0] as! AST.ListItemNode
        #expect(firstItem.children.count == 1, "First item should have one child (paragraph)")

        let firstParagraph = firstItem.children[0] as! AST.ParagraphNode

        // Check for bold text in first item
        let hasBoldText = firstParagraph.children.contains { node in
            if let strongNode = node as? AST.StrongEmphasisNode {
                // Collect all text content from the strong emphasis node
                let textContent = strongNode.children.compactMap { child in
                    if let textNode = child as? AST.TextNode {
                        return textNode.content
                    }
                    return nil
                }.joined()
                return textContent.contains("Fork") && textContent.contains("the") && textContent.contains("repository")
            }
            return false
        }
        #expect(hasBoldText, "First item should contain bold 'Fork the repository' text")

        // Test second item: should contain "Clone your fork" text and code block
        let secondItem = list.items[1] as! AST.ListItemNode
        #expect(secondItem.children.count == 2, "Second item should have 2 children (paragraph + code block)")

        let secondParagraph = secondItem.children[0] as! AST.ParagraphNode

        // Check for code block in second item
        let hasSecondCodeBlock = secondItem.children.contains { node in
            if let codeBlock = node as? AST.CodeBlockNode {
                return codeBlock.language == "bash" &&
                       codeBlock.content.contains("git clone") &&
                       codeBlock.content.contains("cd SwiftMarkdownParser")
            }
            return false
        }
        #expect(hasSecondCodeBlock, "Second item should contain a bash code block with git clone commands")

        // Check for bold text in second item
        let hasCloneBoldText = secondParagraph.children.contains { node in
            if let strongNode = node as? AST.StrongEmphasisNode {
                // Collect all text content from the strong emphasis node
                let textContent = strongNode.children.compactMap { child in
                    if let textNode = child as? AST.TextNode {
                        return textNode.content
                    }
                    return nil
                }.joined()
                return textContent.contains("Clone") && textContent.contains("your") && textContent.contains("fork")
            }
            return false
        }
        #expect(hasCloneBoldText, "Second item should contain bold 'Clone your fork' text")

        // Test third item: should contain "Create a feature branch" text and code block
        let thirdItem = list.items[2] as! AST.ListItemNode
        #expect(thirdItem.children.count == 2, "Third item should have 2 children (paragraph + code block)")

        let thirdParagraph = thirdItem.children[0] as! AST.ParagraphNode

        // Check for code block in third item
        let hasThirdCodeBlock = thirdItem.children.contains { node in
            if let codeBlock = node as? AST.CodeBlockNode {
                return codeBlock.language == "bash" &&
                       codeBlock.content.contains("git checkout -b")
            }
            return false
        }
        #expect(hasThirdCodeBlock, "Third item should contain a bash code block with git checkout command")

        // Check for bold text in third item
        let hasFeatureBoldText = thirdParagraph.children.contains { node in
            if let strongNode = node as? AST.StrongEmphasisNode {
                // Collect all text content from the strong emphasis node
                let textContent = strongNode.children.compactMap { child in
                    if let textNode = child as? AST.TextNode {
                        return textNode.content
                    }
                    return nil
                }.joined()
                return textContent.contains("Create") && textContent.contains("feature") && textContent.contains("branch")
            }
            return false
        }
        #expect(hasFeatureBoldText, "Third item should contain bold 'Create a feature branch' text")
    }

    /// Test HTML rendering of the GitHub instructions markdown
    ///
    /// This test validates that the parser correctly handles complex list structures with multiple code blocks.
    /// Expected behavior: 3 list items with 2 separate code blocks should produce 2 <pre> tags.
    @Test func renderGitHubInstructionsToHTML() async throws {
        let markdown = """
        1. **Fork the repository** on GitHub
        2. **Clone your fork**:
           ```bash
           git clone https://github.com/YOUR_USERNAME/SwiftMarkdownParser.git
           cd SwiftMarkdownParser
           ```
        3. **Create a feature branch**:
           ```bash
           git checkout -b feature/your-feature-name
           ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Basic HTML structure validation
        #expect(html.contains("<ol>"), "HTML should contain ordered list tag")
        #expect(html.contains("</ol>"), "HTML should contain closing ordered list tag")
        #expect(html.contains("<li>"), "HTML should contain list item tags")
        #expect(html.contains("</li>"), "HTML should contain closing list item tags")

        // Check for bold text rendering
        #expect(html.contains("<strong>Fork the repository</strong>"), "HTML should contain bold 'Fork the repository'")
        #expect(html.contains("<strong>Clone your fork</strong>"), "HTML should contain bold 'Clone your fork'")
        #expect(html.contains("<strong>Create a feature branch</strong>"), "HTML should contain bold 'Create a feature branch'")

        // Check for code block rendering - there should be 2 separate code blocks
        let preTagCount = html.components(separatedBy: "<pre>").count - 1
        #expect(preTagCount == 2, "HTML should contain exactly 2 <pre> tags for the 2 code blocks")

        #expect(html.contains("language-bash"), "HTML should specify bash language for code blocks")
        #expect(html.contains("git clone"), "HTML should contain git clone command")
        #expect(html.contains("git checkout -b"), "HTML should contain git checkout command")

        // Verify it's a well-formed HTML structure
        #expect(!html.isEmpty, "HTML output should not be empty")
    }

    // MARK: - Individual Element Tests

    /// Test parsing of simple ordered lists
    @Test func parseOrderedList() async throws {
        let markdown = """
        1. First item
        2. Second item
        3. Third item
        """

        let document = try await parser.parseToAST(markdown)

        let list = try #require(document.children.first as? AST.ListNode, "Expected ListNode")

        #expect(list.isOrdered, "List should be ordered")
        #expect(list.startNumber == 1, "List should start at 1")
        #expect(list.items.count == 3, "List should have 3 items")
    }

    /// Test parsing of bold text within list items
    @Test func parseBoldTextInList() async throws {
        let markdown = "1. **Bold text** in list item"

        let document = try await parser.parseToAST(markdown)

        guard let list = document.children.first as? AST.ListNode,
              let firstItem = list.items.first as? AST.ListItemNode,
              let paragraph = firstItem.children.first as? AST.ParagraphNode else {
            Issue.record("Expected list structure")
            return
        }

        let hasBoldText = paragraph.children.contains { $0 is AST.StrongEmphasisNode }
        #expect(hasBoldText, "List item should contain bold text")
    }

    /// Test parsing of code blocks within list items
    @Test func parseCodeBlockInList() async throws {
        let markdown = """
        1. List item with code:
           ```
           code content
           ```
        """

        let document = try await parser.parseToAST(markdown)

        guard let list = document.children.first as? AST.ListNode,
              let firstItem = list.items.first as? AST.ListItemNode else {
            Issue.record("Expected list structure")
            return
        }

        let hasCodeBlock = firstItem.children.contains { $0 is AST.CodeBlockNode }
        #expect(hasCodeBlock, "List item should contain code block")
    }
}
