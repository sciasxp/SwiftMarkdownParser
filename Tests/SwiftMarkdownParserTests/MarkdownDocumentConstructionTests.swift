import Testing
@testable import SwiftMarkdownParser

@Suite struct MarkdownDocumentConstructionTests {
    @Test func crlfBlankLinesSeparateTopLevelBlocks() throws {
        let markdown = "First\r\n\r\nSecond"

        let document = try SwiftMarkdownParser().parse(markdown)

        #expect(document.children.count == 2)
        #expect(document.children[0].sourceLocation?.offset == 0)
        #expect(document.children[0].sourceLocation?.endOffset == 5)
        #expect(document.children[1].sourceLocation?.offset == 7)
        #expect(document.children[1].sourceLocation?.endOffset == markdown.count)
    }

    @Test func crlfReferenceDefinitionsResolveWithoutShiftingSourceRanges() throws {
        let markdown = "[Swift][language]\r\n\r\n[language]: https://swift.org \"Swift\""

        let document = try SwiftMarkdownParser().parse(markdown)
        let paragraph = try #require(document.children.first as? AST.ParagraphNode)
        let link = try #require(paragraph.children.first as? AST.LinkNode)

        #expect(document.children.count == 1)
        #expect(link.url == "https://swift.org")
        #expect(link.title == "Swift")
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

    @Test(arguments: ["\u{2028}", "\u{2029}", "\u{85}", "\u{0B}", "\u{0C}"])
    func unicodeSeparator_insideHeading_doesNotEndTheLine(separator: String) throws {
        let markdown = "# Title\(separator)More"

        let document = try SwiftMarkdownParser().parse(markdown)
        let heading = try #require(document.children.first as? AST.HeadingNode)

        #expect(document.children.count == 1)
        #expect(plainText(in: heading).hasSuffix("More"))
        #expect(heading.sourceLocation?.endLine == 1)
        #expect(document.sourceLocation?.endLine == 1)
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

    @Test(arguments: ["\u{2028}", "\u{2029}", "\u{85}", "\u{0B}", "\u{0C}"])
    func unicodeSeparator_beforeReferenceDefinition_keepsItInsideParagraph(separator: String) throws {
        let markdown = "[Swift][x]\n\nText\(separator)[x]: https://swift.org"

        let document = try SwiftMarkdownParser().parse(markdown)

        #expect(document.children.count == 2)
        #expect(!containsNode(ofType: AST.LinkNode.self, in: document))
        #expect(plainText(in: document).contains("[x]:"))
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

    @Test func crlfTable_rowsAndCells_rangeOverSourceLines() throws {
        let markdown = "| a | b |\r\n| - | - |\r\n| c | d |"

        let document = try SwiftMarkdownParser().parse(markdown)
        let table = try #require(document.children.first as? AST.GFMTableNode)
        let lastRow = try #require(table.rows.last?.sourceLocation)
        let lastCell = try #require(table.rows.last?.cells.last?.sourceLocation)

        #expect(document.sourceLocation?.endLine == 3)
        #expect(table.sourceLocation?.endOffset == markdown.count)
        #expect([lastRow.line, lastRow.column, lastRow.offset] == [3, 1, 20])
        #expect([lastRow.endLine, lastRow.endColumn, lastRow.endOffset] == [3, 10, 29])
        #expect([lastCell.line, lastCell.column, lastCell.offset] == [3, 7, 26])
        #expect([lastCell.endLine, lastCell.endColumn, lastCell.endOffset] == [3, 8, 27])
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

    @Test func crOnlyTable_documentRowsAndCells_rangeOverSourceLines() throws {
        let markdown = "| a | b |\r| - | - |\r| c | d |\r"

        let document = try SwiftMarkdownParser().parse(markdown)
        let documentRange = try #require(document.sourceLocation)
        let table = try #require(document.children.first as? AST.GFMTableNode)
        let tableRange = try #require(table.sourceLocation)
        let lastRow = try #require(table.rows.last?.sourceLocation)
        let lastCell = try #require(table.rows.last?.cells.last?.sourceLocation)

        #expect(table.rows.count == 2)
        #expect([documentRange.endLine, documentRange.endColumn, documentRange.endOffset] == [4, 1, 30])
        #expect([tableRange.line, tableRange.column, tableRange.offset] == [1, 1, 0])
        #expect([tableRange.endLine, tableRange.endColumn, tableRange.endOffset] == [3, 10, 29])
        #expect([lastRow.line, lastRow.column, lastRow.offset] == [3, 1, 20])
        #expect([lastRow.endLine, lastRow.endColumn, lastRow.endOffset] == [3, 10, 29])
        #expect([lastCell.line, lastCell.column, lastCell.offset] == [3, 7, 26])
        #expect([lastCell.endLine, lastCell.endColumn, lastCell.endOffset] == [3, 8, 27])
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

    @Test func tableRow_atEndOfSourceWithoutLineEnding_rangeEndsAtTheSourceEnd() throws {
        let markdown = "| a | b |\n| - | - |\n| c | d |"

        let document = try SwiftMarkdownParser().parse(markdown)
        let documentRange = try #require(document.sourceLocation)
        let table = try #require(document.children.first as? AST.GFMTableNode)
        let lastRow = try #require(table.rows.last?.sourceLocation)
        let lastCell = try #require(table.rows.last?.cells.last?.sourceLocation)

        #expect([documentRange.endLine, documentRange.endColumn, documentRange.endOffset] == [3, 10, 29])
        #expect(table.sourceLocation?.endOffset == markdown.count)
        #expect([lastRow.line, lastRow.column, lastRow.offset] == [3, 1, 20])
        #expect([lastRow.endLine, lastRow.endColumn, lastRow.endOffset] == [3, 10, 29])
        #expect([lastCell.line, lastCell.column, lastCell.offset] == [3, 7, 26])
        #expect([lastCell.endLine, lastCell.endColumn, lastCell.endOffset] == [3, 8, 27])
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

    @Test func tableRow_followedByLineEnding_rangeEndsAtTheLineEnding() throws {
        let markdown = "| a | b |\n| - | - |\n| c \\| d | e |\nNext"

        let document = try SwiftMarkdownParser().parse(markdown)
        let table = try #require(document.children.first as? AST.GFMTableNode)
        let lastRow = try #require(table.rows.last?.sourceLocation)
        let lastCell = try #require(table.rows.last?.cells.last?.sourceLocation)

        #expect([lastRow.line, lastRow.column, lastRow.offset] == [3, 1, 20])
        #expect([lastRow.endLine, lastRow.endColumn, lastRow.endOffset] == [3, 15, 34])
        #expect([lastCell.line, lastCell.column, lastCell.offset] == [3, 12, 31])
        #expect([lastCell.endLine, lastCell.endColumn, lastCell.endOffset] == [3, 13, 32])
        #expect(table.sourceLocation?.endOffset == 34)
        assertValidRanges(in: document, sourceLength: markdown.count)
    }

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

    @Test("Resolves large consecutive reference-definition sections")
    func manyConsecutiveReferenceDefinitions() throws {
        let referenceCount = 500
        let usages = (0..<referenceCount)
            .map { "[Document \($0)][reference-\($0)]" }
            .joined(separator: "\n\n")
        let definitions = (0..<referenceCount)
            .map { "[reference-\($0)]: https://example.com/documents/\($0) \"Document \($0)\"" }
            .joined(separator: "\n")
        let markdown = usages + "\n\n" + definitions

        let document = try SwiftMarkdownParser().parse(markdown)
        let links = document.depthFirst().compactMap { $0.node as? AST.LinkNode }

        #expect(links.count == referenceCount)
        #expect(links.first?.url == "https://example.com/documents/0")
        #expect(links.last?.url == "https://example.com/documents/499")
        assertValidRanges(in: document, sourceLength: markdown.count)
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

    /// The source text's line table absorbs the per-character charge the
    /// parse used to start with (420 units, measured on `develop`). Each
    /// paragraph is now retokenized as one inline fragment, which costs 136
    /// units more here.
    @Test func simpleDocument_workCost_includesParagraphFragments() throws {
        let source = "# Title\n\nHello *world* and `code`.\n\n- item one\n- item two\n"
        func parser(maximumWork: Int) -> SwiftMarkdownParser {
            SwiftMarkdownParser(resourceLimits: .init(maximumWork: maximumWork))
        }

        _ = try parser(maximumWork: 556).parse(source)
        guard case let .resourceLimitExceeded(resource, _, _) = parsingError(
            from: parser(maximumWork: 555),
            source: source
        ) else {
            Issue.record("Expected a work-limit failure one unit below the cost")
            return
        }
        #expect(resource == .work)
    }

    /// Each inline fragment's line table charges its characters: the two
    /// three-character cells cost 6 units more than on `develop` (279), and
    /// looking past spaces for a line ending costs two more.
    @Test func inlineTableCells_workCost_includesFragmentTables() throws {
        let source = "| *a* | b |\n|---|---|\n| `1` | 2 |\n"
        func parser(maximumWork: Int) -> SwiftMarkdownParser {
            SwiftMarkdownParser(resourceLimits: .init(maximumWork: maximumWork))
        }

        _ = try parser(maximumWork: 287).parse(source)
        guard case let .resourceLimitExceeded(resource, _, _) = parsingError(
            from: parser(maximumWork: 286),
            source: source
        ) else {
            Issue.record("Expected a work-limit failure one unit below the cost")
            return
        }
        #expect(resource == .work)
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

    private func assertValidRanges(in node: any ASTNode, sourceLength: Int) {
        for visit in node.depthFirst() {
            guard let range = visit.node.sourceLocation else {
                Issue.record("Missing source range for \(visit.node.nodeType.rawValue)")
                continue
            }
            #expect(range.offset >= 0)
            #expect(range.endOffset >= range.offset)
            #expect(range.endOffset <= sourceLength)

            if let parentRange = visit.parent?.sourceLocation {
                #expect(range.offset >= parentRange.offset)
                #expect(range.endOffset <= parentRange.endOffset)
            }
        }
    }

    private func containsNode<T: ASTNode>(ofType type: T.Type, in node: any ASTNode) -> Bool {
        node.depthFirst().contains { $0.node is T }
    }

    private func plainText(in node: any ASTNode) -> String {
        node.depthFirst().compactMap { ($0.node as? AST.TextNode)?.content }.joined()
    }
}
