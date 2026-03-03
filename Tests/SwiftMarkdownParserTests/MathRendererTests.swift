import Testing
@testable import SwiftMarkdownParser

/// Tests for math expression rendering functionality
@Suite struct MathRendererTests {

    let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - HTML Block Math Rendering Tests

    @Test func htmlBlockMath_rendersMathDisplayDiv() async throws {
        let markdown = """
        $$
        E = mc^2
        $$
        """

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<div class=\"math math-display\">"))
        #expect(html.contains("E = mc^2"))
        #expect(html.contains("</div>"))
    }

    @Test func htmlBlockMath_escapesHTMLEntities() async throws {
        let markdown = """
        $$
        a < b & c > d
        $$
        """

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<div class=\"math math-display\">"))
        #expect(html.contains("&lt;"))
        #expect(html.contains("&amp;"))
        #expect(html.contains("&gt;"))
    }

    // MARK: - HTML Inline Math Rendering Tests

    @Test func htmlInlineMath_rendersMathInlineSpan() async throws {
        let markdown = "The formula $E = mc^2$ is famous."

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<span class=\"math math-inline\">"))
        #expect(html.contains("E = mc^2"))
        #expect(html.contains("</span>"))
    }

    @Test func htmlInlineMath_escapesHTMLEntities() async throws {
        let markdown = "When $a < b$ holds."

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<span class=\"math math-inline\">"))
        #expect(html.contains("a &lt; b"))
    }

    // MARK: - Integration Tests

    @Test func mathWithHeadings_rendersCorrectly() async throws {
        let markdown = """
        # Math Section

        The quadratic formula is $x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$ and:

        $$
        ax^2 + bx + c = 0
        $$
        """

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<h1>"))
        #expect(html.contains("<span class=\"math math-inline\">"))
        #expect(html.contains("<div class=\"math math-display\">"))
    }

    @Test func mathWithBold_rendersCorrectly() async throws {
        let markdown = "The **important** formula $E = mc^2$ changed physics."

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<strong>important</strong>"))
        #expect(html.contains("<span class=\"math math-inline\">"))
        #expect(html.contains("E = mc^2"))
    }

    @Test func mathWithLists_rendersCorrectly() async throws {
        let markdown = """
        - First: $\\alpha$
        - Second: $\\beta$
        """

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<li>"))
        // The inline math nodes should be present somewhere in the output
        let inlineMathCount = html.components(separatedBy: "math math-inline").count - 1
        #expect(inlineMathCount >= 1, "Should contain at least one inline math span")
    }

    @Test func mathWithCodeBlock_rendersCorrectly() async throws {
        let markdown = """
        Here is math:

        $$
        f(x) = x^2
        $$

        And here is code:

        ```python
        def f(x):
            return x**2
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        #expect(html.contains("<div class=\"math math-display\">"))
        #expect(html.contains("f(x) = x^2"))
        #expect(html.contains("class=\"language-python\""))
        #expect(html.contains("def f(x):"))
    }

    @Test func multipleMathBlocks_renderAll() async throws {
        let markdown = """
        $$
        a^2 + b^2 = c^2
        $$

        Some text.

        $$
        e^{i\\pi} + 1 = 0
        $$
        """

        let html = try await parser.parseToHTML(markdown)

        let displayMathCount = html.components(separatedBy: "math math-display").count - 1
        #expect(displayMathCount == 2, "Should have two math display blocks")
    }
}
