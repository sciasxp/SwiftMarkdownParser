import Testing
@testable import SwiftMarkdownParser

/// Tests for math expression parsing functionality
@Suite struct MathParserTests {

    let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - Block Math Tests

    @Test func blockMath_simple_parsesToMathBlockNode() async throws {
        let markdown = """
        $$
        E = mc^2
        $$
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 1)

        let mathBlock = try #require(ast.children.first as? AST.MathBlockNode)

        #expect(mathBlock.nodeType == .mathBlock)
        #expect(mathBlock.content.contains("E = mc^2"))
    }

    @Test func blockMath_multiline_preservesContent() async throws {
        let markdown = """
        $$
        \\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}
        \\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}
        $$
        """

        let ast = try await parser.parseToAST(markdown)

        let mathBlock = try #require(ast.children.first as? AST.MathBlockNode)

        #expect(mathBlock.content.contains("\\int_0^\\infty"))
        #expect(mathBlock.content.contains("\\sum_{n=1}"))
    }

    @Test func blockMath_withSurroundingContent_parsesCorrectly() async throws {
        let markdown = """
        # Euler's Identity

        The famous formula:

        $$
        e^{i\\pi} + 1 = 0
        $$

        This is beautiful.
        """

        let ast = try await parser.parseToAST(markdown)

        // heading, paragraph, math block, paragraph
        #expect(ast.children.count >= 3)

        let heading = try #require(ast.children[0] as? AST.HeadingNode)
        #expect(heading.level == 1)

        // Find the math block node
        let mathBlocks = ast.children.compactMap { $0 as? AST.MathBlockNode }
        #expect(mathBlocks.count == 1)
        #expect(mathBlocks[0].content.contains("e^{i\\pi}"))
    }

    // MARK: - Inline Math Tests

    @Test func inlineMath_simple_parsesToInlineMathNode() async throws {
        let markdown = "The formula $E = mc^2$ is famous."

        let ast = try await parser.parseToAST(markdown)

        // Should be a paragraph containing text + inline math + text
        let paragraph = try #require(ast.children.first as? AST.ParagraphNode)

        let inlineMathNodes = paragraph.children.compactMap { $0 as? AST.InlineMathNode }
        #expect(inlineMathNodes.count == 1)
        #expect(inlineMathNodes[0].content == "E = mc^2")
    }

    @Test func inlineMath_multipleInOneParagraph_parsesAll() async throws {
        let markdown = "Both $\\alpha$ and $\\beta$ are Greek letters."

        let ast = try await parser.parseToAST(markdown)

        let paragraph = try #require(ast.children.first as? AST.ParagraphNode)

        let inlineMathNodes = paragraph.children.compactMap { $0 as? AST.InlineMathNode }
        #expect(inlineMathNodes.count == 2)
        #expect(inlineMathNodes[0].content == "\\alpha")
        #expect(inlineMathNodes[1].content == "\\beta")
    }

    // MARK: - Edge Cases

    @Test func inlineMath_spaceAfterOpening_treatedAsText() async throws {
        let markdown = "This $ is not math$ here."

        let ast = try await parser.parseToAST(markdown)

        let paragraph = try #require(ast.children.first as? AST.ParagraphNode)

        let inlineMathNodes = paragraph.children.compactMap { $0 as? AST.InlineMathNode }
        #expect(inlineMathNodes.count == 0, "Should not parse as inline math when space after opening $")
    }

    @Test func inlineMath_spaceBeforeClosing_treatedAsText() async throws {
        let markdown = "This $not math $ here."

        let ast = try await parser.parseToAST(markdown)

        let paragraph = try #require(ast.children.first as? AST.ParagraphNode)

        let inlineMathNodes = paragraph.children.compactMap { $0 as? AST.InlineMathNode }
        #expect(inlineMathNodes.count == 0, "Should not parse as inline math when space before closing $")
    }

    @Test func inlineMath_emptyDollars_treatedAsText() async throws {
        let markdown = "Empty $$ should not be inline math."

        let ast = try await parser.parseToAST(markdown)

        let paragraph = try #require(ast.children.first as? AST.ParagraphNode)

        let inlineMathNodes = paragraph.children.compactMap { $0 as? AST.InlineMathNode }
        #expect(inlineMathNodes.count == 0, "Empty $$ should not be inline math")
    }

    @Test func inlineMath_cannotSpanLines_treatedAsText() async throws {
        let markdown = """
        This $starts here
        and ends here$ does not work.
        """

        let ast = try await parser.parseToAST(markdown)

        let allInlineMath = collectNodes(ofType: AST.InlineMathNode.self, from: ast)
        #expect(allInlineMath.count == 0, "Inline math should not span lines")
    }

    @Test func inlineMath_unclosed_treatedAsText() async throws {
        let markdown = "This $unclosed math has no closing delimiter."

        let ast = try await parser.parseToAST(markdown)

        let paragraph = try #require(ast.children.first as? AST.ParagraphNode)

        let inlineMathNodes = paragraph.children.compactMap { $0 as? AST.InlineMathNode }
        #expect(inlineMathNodes.count == 0, "Unclosed $ should not be inline math")
    }

    @Test func escapedDollar_treatedAsText() async throws {
        let markdown = "The price is \\$5.00 and not math."

        let ast = try await parser.parseToAST(markdown)

        let allInlineMath = collectNodes(ofType: AST.InlineMathNode.self, from: ast)
        #expect(allInlineMath.count == 0, "Escaped $ should not trigger math parsing")
    }

    // MARK: - Source Location Tests

    @Test func mathBlock_sourceLocation_isTracked() async throws {
        let markdown = """
        # Heading

        $$
        x^2 + y^2 = r^2
        $$
        """

        let ast = try await parser.parseToAST(markdown)

        let mathBlocks = ast.children.compactMap { $0 as? AST.MathBlockNode }
        #expect(mathBlocks.count == 1)
        #expect(mathBlocks[0].sourceLocation != nil)
    }
}

// MARK: - Helpers

private func collectNodes<T: ASTNode>(ofType type: T.Type, from node: ASTNode) -> [T] {
    var result: [T] = []
    if let match = node as? T {
        result.append(match)
    }
    for child in node.children {
        result.append(contentsOf: collectNodes(ofType: type, from: child))
    }
    return result
}
