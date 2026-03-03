import Testing
import Foundation
@testable import SwiftMarkdownParser

/// Test suite for the SwiftMarkdownParser functionality.
///
/// This test suite covers the AST-focused parsing functionality,
/// including parsing various markdown elements and error handling.
@Suite struct SwiftMarkdownParserTests {
    let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - Parser Tests

    @Test func parse_emptyString_returnsEmptyDocument() async throws {
        let document = try await parser.parseToAST("")
        #expect(document.children.count == 0)
    }

    @Test func parse_simpleParagraph_returnsDocumentWithParagraph() async throws {
        let document = try await parser.parseToAST("This is a simple paragraph.")
        #expect(document.children.count == 1)
        #expect(document.children.first?.nodeType == .paragraph)
    }

    // MARK: - HTML Renderer Tests

    @Test func htmlRenderer_renderTextNode_returnsEscapedHTML() async throws {
        let renderer = HTMLRenderer()
        let textNode = AST.TextNode(content: "Hello & <world>")
        let html = try await renderer.render(node: textNode)
        #expect(html == "Hello &amp; &lt;world&gt;")
    }

    @Test func htmlRenderer_renderParagraphNode_returnsWrappedHTML() async throws {
        let renderer = HTMLRenderer()
        let textNode = AST.TextNode(content: "Hello, World!")
        let paragraph = AST.ParagraphNode(children: [textNode])
        let html = try await renderer.render(node: paragraph)
        #expect(html.contains("<p>Hello, World!</p>"))
    }

    @Test func htmlRenderer_renderHeadingNode_returnsHeadingHTML() async throws {
        let renderer = HTMLRenderer()
        let textNode = AST.TextNode(content: "Test Heading")
        let heading = AST.HeadingNode(level: 2, children: [textNode])
        let html = try await renderer.render(node: heading)
        #expect(html.contains("<h2>Test Heading</h2>"))
    }

    @Test func htmlRenderer_renderLinkNode_returnsLinkHTML() async throws {
        let renderer = HTMLRenderer()
        let textNode = AST.TextNode(content: "Swift")
        let link = AST.LinkNode(url: "https://swift.org", title: "Swift.org", children: [textNode])
        let html = try await renderer.render(node: link)
        #expect(html == "<a href=\"https://swift.org\" title=\"Swift.org\">Swift</a>")
    }

    // MARK: - GFM Tests

    @Test func gfm_parseSimpleTableLine() async throws {
        print("[TEST] Starting simple table line test...")

        let markdown = "| Name | Age |"

        print("[TEST] Markdown input: '\(markdown)'")
        print("[TEST] Calling parseToAST...")

        let ast = try await parser.parseToAST(markdown)

        print("[TEST] Parse completed! Children count: \(ast.children.count)")
        print("[TEST] First child type: \(type(of: ast.children.first!))")

        // This should still be parsed as a paragraph (single line can't be a table without separator)
        #expect(ast.children.first is AST.ParagraphNode)
    }

    @Test func gfm_parseMinimalTable() async throws {
        print("[TEST] Starting minimal table test...")

        // For now, test that we can parse a single line without hanging
        let markdown = "| A | B |"

        print("[TEST] Markdown input: '\(markdown)'")
        print("[TEST] Calling parseToAST...")

        let ast = try await parser.parseToAST(markdown)

        print("[TEST] Parse completed! Children count: \(ast.children.count)")
        print("[TEST] First child type: \(type(of: ast.children.first!))")

        // This should be parsed as a paragraph (single line can't be a table)
        #expect(ast.children.first is AST.ParagraphNode)
    }

    @Test func gfm_parseTable() async throws {
        print("[TEST] Starting table parsing test...")

        let markdown = """
        | Name | Age | City |
        |------|-----|------|
        | John | 25  | NYC  |
        | Jane | 30  | LA   |
        """

        print("[TEST] Markdown input: '\(markdown)'")

        let parser = SwiftMarkdownParser()
        print("[TEST] Calling parseToAST...")
        let document = try await parser.parseToAST(markdown)
        print("[TEST] Parse completed! Children count: \(document.children.count)")

        // Should have one table
        #expect(document.children.count == 1)

        let table = try #require(document.children.first as? AST.GFMTableNode, "Expected GFMTableNode, got \(type(of: document.children.first))")

        print("[TEST] Found table with \(table.rows.count) rows")

        // Should have 3 rows (header + 2 data rows)
        #expect(table.rows.count == 3)

        // Check header row
        let headerRow = table.rows[0]
        #expect(headerRow.isHeader)
        #expect(headerRow.cells.count == 3)
        #expect(headerRow.cells[0].content == "Name")
        #expect(headerRow.cells[1].content == "Age")
        #expect(headerRow.cells[2].content == "City")

        // Check data rows
        let dataRow1 = table.rows[1]
        #expect(!dataRow1.isHeader)
        #expect(dataRow1.cells.count == 3)
        #expect(dataRow1.cells[0].content == "John")
        #expect(dataRow1.cells[1].content == "25")
        #expect(dataRow1.cells[2].content == "NYC")

        let dataRow2 = table.rows[2]
        #expect(!dataRow2.isHeader)
        #expect(dataRow2.cells.count == 3)
        #expect(dataRow2.cells[0].content == "Jane")
        #expect(dataRow2.cells[1].content == "30")
        #expect(dataRow2.cells[2].content == "LA")

        // Check alignments
        #expect(table.alignments.count == 3)
        #expect(table.alignments[0] == .none)
        #expect(table.alignments[1] == .none)
        #expect(table.alignments[2] == .none)

        print("[TEST] Table parsing test completed successfully!")
    }

    @Test func gfm_parseTaskList() async throws {
        // Test single task list item
        let markdown = "- [x] Completed task"

        let ast = try await parser.parseToAST(markdown)

        let list = try #require(ast.children.first as? AST.ListNode, "Expected ListNode")

        #expect(list.items.count == 1)

        // Check that the item was converted to a GFMTaskListItemNode
        let taskItem = try #require(list.items[0] as? AST.GFMTaskListItemNode, "Expected GFMTaskListItemNode")

        #expect(taskItem.isChecked)

        // Test unchecked task
        let markdown2 = "- [ ] Incomplete task"
        let ast2 = try await parser.parseToAST(markdown2)

        let list2 = try #require(ast2.children.first as? AST.ListNode, "Expected ListNode for second test")

        let taskItem2 = try #require(list2.items[0] as? AST.GFMTaskListItemNode, "Expected GFMTaskListItemNode for second test")

        #expect(!taskItem2.isChecked)
    }

    @Test func gfm_parseStrikethrough() async throws {
        let markdown = "This is ~~strikethrough~~ text."
        let ast = try await parser.parseToAST(markdown)

        let paragraph = try #require(ast.children.first as? AST.ParagraphNode, "Expected ParagraphNode")

        // Should have 7 nodes: "This", " ", "is", " ", StrikethroughNode, " ", "text."
        #expect(paragraph.children.count == 7)

        // Check that the 5th node (index 4) is a strikethrough node
        let strikethroughNode = paragraph.children[4]
        #expect(strikethroughNode.nodeType == .strikethrough)

        // Verify it's actually a StrikethroughNode with correct content
        let strikethrough = try #require(strikethroughNode as? AST.StrikethroughNode, "Expected StrikethroughNode")

        #expect(strikethrough.content.count == 1)
        let strikethroughText = try #require(strikethrough.content.first as? AST.TextNode, "Expected TextNode in strikethrough content")
        #expect(strikethroughText.content == "strikethrough")
    }

    @Test func gfm_parseAutolinks() async throws {
        let markdown = "Visit https://example.com"
        let ast = try await parser.parseToAST(markdown)
        let paragraph = try #require(ast.children.first as? AST.ParagraphNode, "Expected ParagraphNode")

        // Should have 3 nodes: "Visit", " ", AutolinkNode
        #expect(paragraph.children.count == 3)

        // Check that the third node is an autolink
        let autolinkNode = paragraph.children[2]
        #expect(autolinkNode.nodeType == .autolink)

        // Verify it's actually an AutolinkNode with correct content
        let autolink = try #require(autolinkNode as? AST.AutolinkNode, "Expected AutolinkNode")

        #expect(autolink.url == "https://example.com")
        #expect(autolink.text == "https://example.com")
    }

    // MARK: - List Tests

    @Test func parseMultipleListItems_unordered() async throws {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 1)
        let list = try #require(ast.children.first as? AST.ListNode, "Expected ListNode")

        #expect(!list.isOrdered)
        #expect(list.items.count == 3)

        // Verify each item
        for (index, item) in list.items.enumerated() {
            guard let listItem = item as? AST.ListItemNode else {
                Issue.record("Expected ListItemNode at index \(index)")
                continue
            }
            #expect(listItem.children.count == 1)

            guard let paragraph = listItem.children.first as? AST.ParagraphNode else {
                Issue.record("Expected ParagraphNode in list item at index \(index)")
                continue
            }

            // Each paragraph should contain text nodes with "Item N"
            let textContent = paragraph.children.compactMap { ($0 as? AST.TextNode)?.content }.joined()
            #expect(textContent == "Item \(index + 1)")
        }
    }

    @Test func parseMultipleListItems_ordered() async throws {
        let markdown = """
        1. First item
        2. Second item
        3. Third item
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 1)
        let list = try #require(ast.children.first as? AST.ListNode, "Expected ListNode")

        #expect(list.isOrdered)
        #expect(list.startNumber == 1)
        #expect(list.items.count == 3)

        // Verify first item content
        guard let firstItem = list.items.first as? AST.ListItemNode,
              let paragraph = firstItem.children.first as? AST.ParagraphNode else {
            Issue.record("Expected ListItemNode with ParagraphNode")
            return
        }

        let textContent = paragraph.children.compactMap { ($0 as? AST.TextNode)?.content }.joined()
        #expect(textContent == "First item")
    }

    @Test func debug_pipeCharacter() async throws {
        print("[DEBUG] Starting pipe character test...")

        // Test with just pipe characters to see if that's the trigger
        let markdown = "| A |"

        print("[DEBUG] Markdown: '\(markdown)'")
        print("[DEBUG] About to call parseToAST...")

        let startTime = Date()
        let result = try await parser.parseToAST(markdown)
        let endTime = Date()

        print("[DEBUG] Parse completed in \(endTime.timeIntervalSince(startTime)) seconds")
        print("[DEBUG] Children: \(result.children.count)")

        #expect(result.children.count >= 0)
    }

    @Test func debug_simpleText() async throws {
        print("[DEBUG] Starting simple text test...")

        // Test with just simple text that should not trigger table parsing
        let markdown = "Hello world"

        print("[DEBUG] Markdown: '\(markdown)'")
        print("[DEBUG] About to call parseToAST...")

        let startTime = Date()
        let result = try await parser.parseToAST(markdown)
        let endTime = Date()

        print("[DEBUG] Parse completed in \(endTime.timeIntervalSince(startTime)) seconds")
        print("[DEBUG] Children: \(result.children.count)")

        #expect(result.children.count == 1)
        #expect(result.children.first is AST.ParagraphNode)
    }

    @Test func debug_tableHang() async throws {
        print("[DEBUG] Starting minimal table debug test...")

        // Start with the simplest possible table
        let markdown = """
        | A |
        |---|
        | B |
        """

        print("[DEBUG] Markdown: '\(markdown)'")
        print("[DEBUG] About to call parseToAST...")

        // Create a simple task that we can monitor
        let startTime = Date()
        let result = try await parser.parseToAST(markdown)
        let endTime = Date()

        print("[DEBUG] Parse completed in \(endTime.timeIntervalSince(startTime)) seconds")
        print("[DEBUG] Children: \(result.children.count)")

        // If we get here, it didn't hang
        #expect(result.children.count >= 0)
    }

    @Test func debug_tableStructure() async throws {
        print("[DEBUG] Starting table structure test...")

        // Test with the exact table structure that was hanging
        let markdown = """
        | A |
        |---|
        | B |
        """

        print("[DEBUG] Markdown: '\(markdown)'")
        print("[DEBUG] About to call parseToAST...")

        let startTime = Date()
        let result = try await parser.parseToAST(markdown)
        let endTime = Date()

        print("[DEBUG] Parse completed in \(endTime.timeIntervalSince(startTime)) seconds")
        print("[DEBUG] Children: \(result.children.count)")

        // Since table parsing is disabled, this should be parsed as paragraphs
        #expect(result.children.count >= 1)
    }

    @Test func debug_tokenizerOnly() async throws {
        print("[DEBUG] Starting tokenizer-only test...")

        let markdown = """
        | A |
        |---|
        | B |
        """

        print("[DEBUG] About to create tokenizer...")
        let tokenizer = MarkdownTokenizer(markdown)
        print("[DEBUG] About to tokenize...")
        let tokens = tokenizer.tokenize()
        print("[DEBUG] Tokenization completed! Got \(tokens.count) tokens")

        #expect(tokens.count > 0)
    }

    @Test func tokenizer_edge_cases() async throws {
        // Test edge cases that previously caused infinite loops

        // Test mixed pipes and dashes (table separator line)
        let mixed = "|----------|----------|"
        let tokenizer = MarkdownTokenizer(mixed)
        let tokens = tokenizer.tokenize()

        #expect(tokens.count > 0, "Mixed pipes and dashes should produce tokens")
        #expect(tokens.contains { $0.type == .pipe }, "Should contain pipe tokens")
        #expect(tokens.contains { $0.type == .text }, "Should contain text tokens")
    }

    // MARK: - GFMTableCellNode Fix Tests

    @Test func gfmTableCellNode_nestedInlineContentExtraction() async throws {
        // Test that the fix correctly extracts plain text from nested inline elements

        // Create some nested inline elements
        let boldText = AST.StrongEmphasisNode(children: [
            AST.TextNode(content: "Bold")
        ])

        let regularText = AST.TextNode(content: " text ")

        let emphasisText = AST.EmphasisNode(children: [
            AST.TextNode(content: "italic")
        ])

        let linkText = AST.LinkNode(
            url: "https://example.com",
            title: "Example",
            children: [AST.TextNode(content: "link")]
        )

        let codeSpan = AST.CodeSpanNode(content: "code")

        // Create a table cell with nested inline elements
        let tableCell = AST.GFMTableCellNode(
            children: [boldText, regularText, emphasisText, linkText, codeSpan],
            isHeader: false,
            alignment: .none
        )

        // Test that the content extraction works correctly
        let expectedContent = "Bold text italiclinkcode"
        let actualContent = tableCell.content

        #expect(actualContent == expectedContent, "Content extraction should work for nested inline elements")

        // Test that children are preserved
        #expect(tableCell.children.count == 5, "Children should be preserved correctly")

        // Test that the cell properties are correct
        #expect(!tableCell.isHeader, "Header flag should be preserved")
        #expect(tableCell.alignment == .none, "Alignment should be preserved")
    }

    @Test func gfmTableCellNode_emptyChildren() async throws {
        // Test with empty children array
        let tableCell = AST.GFMTableCellNode(
            children: [],
            isHeader: true,
            alignment: .center
        )

        #expect(tableCell.content == "", "Empty children should result in empty content")
        #expect(tableCell.children.count == 0, "Children should be empty")
        #expect(tableCell.isHeader, "Header flag should be preserved")
        #expect(tableCell.alignment == .center, "Alignment should be preserved")
    }

    @Test func gfmTableCellNode_deeplyNestedContent() async throws {
        // Test with deeply nested content
        let deeplyNestedText = AST.EmphasisNode(children: [
            AST.StrongEmphasisNode(children: [
                AST.TextNode(content: "Deep")
            ])
        ])

        let tableCell = AST.GFMTableCellNode(
            children: [deeplyNestedText],
            isHeader: false,
            alignment: .left
        )

        #expect(tableCell.content == "Deep", "Deeply nested content should be extracted")
        #expect(tableCell.children.count == 1, "Children should be preserved")
    }

    @Test func gfmTableCellNode_mixedContentTypes() async throws {
        // Test with various content types
        let imageNode = AST.ImageNode(url: "image.jpg", altText: "Alt text")
        let autolinkNode = AST.AutolinkNode(url: "https://example.com", text: "example.com")
        let htmlInlineNode = AST.HTMLInlineNode(content: "<span>HTML</span>")

        let tableCell = AST.GFMTableCellNode(
            children: [imageNode, autolinkNode, htmlInlineNode],
            isHeader: false,
            alignment: .right
        )

        let expectedContent = "Alt textexample.com<span>HTML</span>"
        #expect(tableCell.content == expectedContent, "Mixed content types should be extracted correctly")
    }
}
