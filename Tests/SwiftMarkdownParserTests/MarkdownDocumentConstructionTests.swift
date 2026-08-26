import Testing
@testable import SwiftMarkdownParser

@Suite struct MarkdownDocumentConstructionTests {
    @Test func synchronousInterfaceBuildsACompleteSemanticDocument() throws {
        let markdown = """
        [Swift][language]

        - [x] Parse **once**

        | Feature | State |
        |:--------|:-----:|
        | Inline | ~~resolved~~ |

        [language]: https://swift.org "Swift"
        """

        let document = try SwiftMarkdownParser().parse(markdown)

        let paragraph = try #require(document.children.first as? AST.ParagraphNode)
        let link = try #require(paragraph.children.first as? AST.LinkNode)
        #expect(link.url == "https://swift.org")
        #expect(link.title == "Swift")

        let list = try #require(document.children.first { $0 is AST.ListNode } as? AST.ListNode)
        let task = try #require(list.items.first as? AST.GFMTaskListItemNode)
        #expect(task.isChecked)
        #expect(containsNode(ofType: AST.StrongEmphasisNode.self, in: task))

        let table = try #require(document.children.first { $0 is AST.GFMTableNode } as? AST.GFMTableNode)
        #expect(table.rows.allSatisfy { row in row.cells.allSatisfy { !$0.children.isEmpty } })
        #expect(containsNode(ofType: AST.StrikethroughNode.self, in: table))
        #expect(!containsNode(ofType: AST.FragmentNode.self, in: document))
    }

    @Test func parserProducedNodesHaveStableSourceRanges() throws {
        let markdown = """
        # Title

        A **strong** paragraph with https://swift.org.

        - [ ] A task

        | Name | Value |
        |------|-------|
        | one  | `two` |

        ```mermaid
        graph TD
          A --> B
        ```
        """

        let document = try SwiftMarkdownParser().parse(markdown)
        assertValidRanges(in: document, sourceLength: markdown.count)
        #expect(document.sourceLocation?.offset == 0)
        #expect(document.sourceLocation?.endOffset == markdown.count)
    }

    @Test func referenceLabelsAreNormalizedAndFirstDefinitionWins() throws {
        let markdown = """
        [Swift Language]

        [  SWIFT   language ]: https://swift.org "First"
        [swift language]: https://example.com "Second"
        """

        let document = try SwiftMarkdownParser().parse(markdown)
        let paragraph = try #require(document.children.first as? AST.ParagraphNode)
        let link = try #require(paragraph.children.first as? AST.LinkNode)

        #expect(link.url == "https://swift.org")
        #expect(link.title == "First")
    }

    @Test func referenceLikeTextInsideCodeFenceRemainsCode() throws {
        let markdown = """
        ```text
        [inside]: https://example.com
        ```

        [inside]
        """

        let document = try SwiftMarkdownParser().parse(markdown)
        let code = try #require(document.children.first as? AST.CodeBlockNode)
        let paragraph = try #require(document.children.last as? AST.ParagraphNode)

        #expect(code.content.contains("[inside]: https://example.com"))
        #expect(!containsNode(ofType: AST.LinkNode.self, in: paragraph))
        #expect(plainText(in: paragraph) == "[inside]")
    }

    @Test func incompleteInlineSyntaxRemainsLiteralText() throws {
        let markdown = "Prefix **unclosed and [broken](destination"
        let document = try SwiftMarkdownParser().parse(markdown)
        let paragraph = try #require(document.children.first as? AST.ParagraphNode)

        #expect(plainText(in: paragraph) == markdown)
        #expect(!containsNode(ofType: AST.StrongEmphasisNode.self, in: paragraph))
        #expect(!containsNode(ofType: AST.LinkNode.self, in: paragraph))
    }

    @Test func sourceLengthLimitFailsAtomically() {
        let parser = SwiftMarkdownParser(resourceLimits: .init(
            maximumSourceLength: 4,
            maximumNestingDepth: 10,
            maximumWork: 1_000
        ))

        #expect(throws: MarkdownParsingError.sourceTooLarge(limit: 4, actual: 5)) {
            try parser.parse("12345")
        }
    }

    @Test func workLimitIsDeterministic() {
        let source = "**repeatable**"
        let parser = SwiftMarkdownParser(resourceLimits: .init(
            maximumSourceLength: 100,
            maximumNestingDepth: 10,
            maximumWork: source.count + 2
        ))

        let first = parsingError(from: parser, source: source)
        let second = parsingError(from: parser, source: source)
        #expect(first == second)

        guard case let .resourceLimitExceeded(resource, limit, actual) = first else {
            Issue.record("Expected deterministic work-limit failure")
            return
        }
        #expect(resource == .work)
        #expect(actual > limit)
    }

    @Test func nestingLimitCoversBlockAndInlineConstruction() {
        let parser = SwiftMarkdownParser(resourceLimits: .init(
            maximumSourceLength: 1_000,
            maximumNestingDepth: 2,
            maximumWork: 100_000
        ))

        #expect(throws: MarkdownParsingError.self) {
            try parser.parse("> > > too deep")
        }
        #expect(throws: MarkdownParsingError.self) {
            try parser.parse("*[nested](destination)*")
        }
    }

    @Test func incompleteBlockMathRemainsLiteralText() throws {
        let markdown = "$$\nunclosed"
        let document = try SwiftMarkdownParser().parse(markdown)
        #expect(plainText(in: document) == "$$unclosed")
        #expect(!containsNode(ofType: AST.MathBlockNode.self, in: document))
    }

    @Test func oneParserCanBeUsedConcurrently() async throws {
        let parser = SwiftMarkdownParser()

        try await withThrowingTaskGroup(of: Int.self) { group in
            for index in 0..<24 {
                group.addTask {
                    let document = try parser.parse("# \(index)\n\n- [x] **done**")
                    return document.children.count
                }
            }

            for try await childCount in group {
                #expect(childCount == 2)
            }
        }
    }

    private func parsingError(
        from parser: SwiftMarkdownParser,
        source: String
    ) -> MarkdownParsingError? {
        do {
            _ = try parser.parse(source)
            return nil
        } catch let error as MarkdownParsingError {
            return error
        } catch {
            Issue.record("Unexpected error family: \(error)")
            return nil
        }
    }

    private func assertValidRanges(in node: ASTNode, sourceLength: Int) {
        guard let range = node.sourceLocation else {
            Issue.record("Missing source range for \(node.nodeType.rawValue)")
            return
        }
        #expect(range.offset >= 0)
        #expect(range.endOffset >= range.offset)
        #expect(range.endOffset <= sourceLength)

        for child in node.children {
            if let childRange = child.sourceLocation {
                #expect(childRange.offset >= range.offset)
                #expect(childRange.endOffset <= range.endOffset)
            }
            assertValidRanges(in: child, sourceLength: sourceLength)
        }
    }

    private func containsNode<T: ASTNode>(ofType type: T.Type, in node: ASTNode) -> Bool {
        if node is T { return true }
        return node.children.contains { containsNode(ofType: type, in: $0) }
    }

    private func plainText(in node: ASTNode) -> String {
        if let text = node as? AST.TextNode { return text.content }
        return node.children.map(plainText).joined()
    }
}
