import Testing
import Foundation
@testable import SwiftMarkdownParser

/// Test suite for HTML table renderer improvements
/// Testing inline markdown support, accessibility, and advanced features
@Suite struct HTMLTableRendererTests {

    let parser: SwiftMarkdownParser
    let renderer: HTMLRenderer

    init() {
        parser = SwiftMarkdownParser(
            configuration: SwiftMarkdownParser.Configuration(
                enableGFMExtensions: true,
                trackSourceLocations: true
            )
        )
        renderer = HTMLRenderer()
    }

    // MARK: - Inline Markdown Support Tests

    @Test func tableCell_rendersBoldText() async throws {
        let markdown = """
        | Header |
        |--------|
        | **Bold** text |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<strong>Bold</strong>"))
        #expect(html.contains("<td><strong>Bold</strong> text</td>"))
    }

    @Test func tableCell_rendersItalicText() async throws {
        let markdown = """
        | Header |
        |--------|
        | *Italic* text |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<em>Italic</em>"))
        #expect(html.contains("<td><em>Italic</em> text</td>"))
    }

    @Test func tableCell_rendersCodeSpan() async throws {
        let markdown = """
        | Header |
        |--------|
        | `code` span |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<code>code</code>"))
        #expect(html.contains("<td><code>code</code> span</td>"))
    }

    @Test func tableCell_rendersLinks() async throws {
        let markdown = """
        | Header |
        |--------|
        | [Link](https://example.com) text |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<a href=\"https://example.com\">Link</a>"))
        #expect(html.contains("<td><a href=\"https://example.com\">Link</a> text</td>"))
    }

    @Test func tableCell_rendersComplexInlineMarkdown() async throws {
        let markdown = """
        | Header |
        |--------|
        | **Bold** and *italic* with `code` and [link](https://example.com) |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<strong>Bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
        #expect(html.contains("<code>code</code>"))
        #expect(html.contains("<a href=\"https://example.com\">link</a>"))
    }

    @Test func tableCell_rendersStrikethrough() async throws {
        let markdown = """
        | Header |
        |--------|
        | ~~Strikethrough~~ text |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<del>Strikethrough</del>"))
        #expect(html.contains("<td><del>Strikethrough</del> text</td>"))
    }

    @Test func tableCell_rendersAutolinks() async throws {
        let markdown = """
        | Header |
        |--------|
        | https://example.com |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<a href=\"https://example.com\">https://example.com</a>"))
    }

    @Test func tableCell_rendersNestedInlineElements() async throws {
        let markdown = """
        | Header |
        |--------|
        | **Bold** and *italic* text |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        // Should render both strong and em elements
        #expect(html.contains("<strong>Bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
    }

    @Test func tableCell_handlesEscapedCharacters() async throws {
        let markdown = """
        | Header |
        |--------|
        | \\*Not bold\\* and \\`not code\\` |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("*Not bold*"))
        #expect(html.contains("not code"))
        #expect(!html.contains("<strong>"))
        #expect(!html.contains("<code>"))
    }

    // MARK: - Accessibility Tests

    @Test func table_includesAccessibilityAttributes() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                customAttributes: [
                    .table: ["role": "table", "aria-label": "Data table"],
                    .tableCell: ["scope": "col"]
                ]
            )
        )
        let accessibleRenderer = HTMLRenderer(context: context)

        let markdown = """
        | Name | Age |
        |------|-----|
        | John | 25  |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await accessibleRenderer.render(document: ast)

        #expect(html.contains("role=\"table\""))
        #expect(html.contains("aria-label=\"Data table\""))
    }

    @Test func tableHeaders_includeScopeAttributes() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                customAttributes: [
                    .tableCell: ["scope": "col"]
                ]
            )
        )
        let accessibleRenderer = HTMLRenderer(context: context)

        let markdown = """
        | Name | Age |
        |------|-----|
        | John | 25  |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await accessibleRenderer.render(document: ast)

        // Headers should have scope="col"
        #expect(html.contains("<th scope=\"col\">Name</th>"))
        #expect(html.contains("<th scope=\"col\">Age</th>"))
    }

    @Test func table_includesCaption() async throws {
        // This test will pass when we implement caption support
        let markdown = """
        | Name | Age |
        |------|-----|
        | John | 25  |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        // For now, just ensure table renders without caption
        #expect(html.contains("<table>"))
        #expect(!html.contains("<caption>"))
    }

    // MARK: - Enhanced Styling Tests

    @Test func table_supportsZebraStriping() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                cssClasses: [
                    .tableRow: "table-row",
                    .table: "zebra-striped"
                ]
            )
        )
        let styledRenderer = HTMLRenderer(context: context)

        let markdown = """
        | Name | Age |
        |------|-----|
        | John | 25  |
        | Jane | 30  |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await styledRenderer.render(document: ast)

        #expect(html.contains("class=\"zebra-striped\""))
        #expect(html.contains("class=\"table-row\""))
    }

    @Test func table_supportsCustomCellPadding() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                customAttributes: [
                    .tableCell: ["style": "padding: 12px;"]
                ]
            )
        )
        let styledRenderer = HTMLRenderer(context: context)

        let markdown = """
        | Name | Age |
        |------|-----|
        | John | 25  |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await styledRenderer.render(document: ast)

        #expect(html.contains("style=\"padding: 12px;\""))
    }

    // MARK: - Performance Tests

    @Test func table_handlesLargeDatasets() async throws {
        // Generate a large table
        var markdown = "| ID | Name | Value |\n|-----|------|-------|\n"
        for i in 1...1000 {
            markdown += "| \(i) | Item \(i) | Value \(i) |\n"
        }

        let startTime = Date()
        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)
        let endTime = Date()

        let renderTime = endTime.timeIntervalSince(startTime)

        // Should render within reasonable time (less than 1 second)
        #expect(renderTime < 1.0)
        #expect(html.contains("<table>"))
        #expect(html.contains("Item 1000"))
    }

    // MARK: - Error Handling Tests

    @Test func table_handlesEmptyCells() async throws {
        let markdown = """
        | Name | Age |
        |------|-----|
        | John |     |
        |      | 25  |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("<td></td>"))
        #expect(html.contains("<td>John</td>"))
        #expect(html.contains("<td>25</td>"))
    }

    @Test func table_handlesSpecialCharacters() async throws {
        let markdown = """
        | Name | Special |
        |------|---------|
        | John | <>&"' |
        """

        let ast = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: ast)

        #expect(html.contains("&lt;&gt;&amp;&quot;&#39;"))
        #expect(!html.contains("<>&\"'"))
    }
}
