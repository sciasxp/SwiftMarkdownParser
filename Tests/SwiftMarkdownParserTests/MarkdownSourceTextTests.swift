import Testing
@testable import SwiftMarkdownParser

@Suite struct MarkdownSourceTextTests {
    @Test(arguments: ["\n", "\r", "\r\n"] as [Character])
    func isLineEnding_commonMarkLineEnding_returnsTrue(character: Character) {
        #expect(MarkdownSourceText.isLineEnding(character))
    }

    @Test(arguments: ["\u{2028}", "\u{2029}", "\u{85}", "\u{0B}", "\u{0C}", " ", "\t"] as [Character])
    func isLineEnding_otherWhitespace_returnsFalse(character: Character) {
        #expect(!MarkdownSourceText.isLineEnding(character))
    }

    @Test func lines_mixedLineEndings_splitAtEachEnding() {
        let text = makeText("a\nb\r\nc\rd")

        #expect(text.lines.map(\.number) == [1, 2, 3, 4])
        #expect(text.lines.map { text.string(in: $0.contentRange) } == ["a", "b", "c", "d"])
        #expect(text.lines.map(\.hasLineEnding) == [true, true, true, false])
    }

    @Test func lines_trailingLineEnding_endWithEmptyLine() {
        let text = makeText("a\n")

        #expect(text.lines.count == 2)
        #expect(text.lines.last?.contentRange == 2..<2)
        #expect(text.lines.last?.hasLineEnding == false)
    }

    @Test func lines_emptySource_containSingleEmptyLine() {
        let text = makeText("")

        #expect(text.lines.count == 1)
        #expect(text.lines.first?.contentRange == 0..<0)
    }

    @Test func lines_unicodeSeparators_stayOnOneLine() {
        let text = makeText("a\u{2028}b\u{2029}c\u{85}d\u{0B}e\u{0C}f")

        #expect(text.lines.count == 1)
        #expect(text.lines.first?.contentRange == 0..<text.count)
    }

    @Test func location_crlfSource_countsCRLFAsOneCharacter() {
        let text = makeText("ab\r\ncd")

        #expect(position(text.location(at: 2)) == Position(line: 1, column: 3, offset: 2))
        #expect(position(text.location(at: 3)) == Position(line: 2, column: 1, offset: 3))
        #expect(position(text.location(at: 5)) == Position(line: 2, column: 3, offset: 5))
    }

    @Test func location_customOrigin_offsetsColumnsOnFirstLineOnly() {
        let text = MarkdownSourceText(
            "ab\ncd",
            startingAt: sourcePosition(line: 3, column: 5, offset: 20),
            budget: unlimitedBudget()
        )

        #expect(position(text.location(at: 0)) == Position(line: 3, column: 5, offset: 20))
        #expect(position(text.location(at: 2)) == Position(line: 3, column: 7, offset: 22))
        #expect(position(text.location(at: 3)) == Position(line: 4, column: 1, offset: 23))
    }

    @Test func range_spanningLineEnding_endsAfterLastCharacter() {
        let text = makeText("ab\r\ncd")

        let range = text.range(0..<5)

        #expect(position(range) == Position(line: 1, column: 1, offset: 0))
        #expect(endPosition(range) == Position(line: 2, column: 3, offset: 5))
    }

    @Test func blankingCharacters_definitionLine_preservesTabsAndLineTable() {
        let text = makeText("x\n[a]:\tb\ny")
        let definition = text.lines[1].contentRange

        let blanked = text.blankingCharacters(in: [definition])

        #expect(blanked.string(in: definition) == "    \t ")
        #expect(blanked.string(in: 0..<blanked.count) == "x\n    \t \ny")
        #expect(blanked.lines == text.lines)
    }

    @Test func blankingCharacters_noRanges_keepsCharacters() {
        let text = makeText("a\nb")

        #expect(text.blankingCharacters(in: []).characters == text.characters)
    }

    @Test func init_parsingBudget_chargesOneUnitPerCharacter() {
        let budget = unlimitedBudget()

        let text = MarkdownSourceText("ab\r\ncd", budget: budget)

        #expect(budget.consumedWork == text.count)
    }

    // MARK: - Helpers

    private struct Position: Equatable {
        let line: Int
        let column: Int
        let offset: Int
    }

    private func position(_ location: MarkdownSourceLocation) -> Position {
        Position(line: location.line, column: location.column, offset: location.offset)
    }

    private func endPosition(_ location: MarkdownSourceLocation) -> Position {
        Position(line: location.endLine, column: location.endColumn, offset: location.endOffset)
    }

    private func makeText(_ source: String) -> MarkdownSourceText {
        MarkdownSourceText(source, budget: unlimitedBudget())
    }

    private func unlimitedBudget() -> ParsingBudget {
        ParsingBudget(maximumWork: .max)
    }
}
