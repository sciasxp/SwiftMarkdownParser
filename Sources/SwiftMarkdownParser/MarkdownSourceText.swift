/// The Source Text of one Markdown Source: its characters plus a table of line
/// starts, built once per text.
///
/// This is the single authority on what ends a line, on `SourceLocation`
/// arithmetic for a position, and on iterating lines. Only the CommonMark line
/// endings end a line: LF, CR, and CRLF (one Swift `Character`). Other Unicode
/// separators, such as U+2028, U+2029, NEL, VT, and FF, are ordinary
/// whitespace. Offsets and columns count Swift `Character` values.
struct MarkdownSourceText {
    /// One line of the text. Ranges are offsets local to the text.
    struct Line: Equatable {
        /// Line number in the coordinate space of the text's origin (1-based).
        let number: Int

        /// Characters of the line, excluding its line ending.
        let contentRange: Range<Int>

        /// Whether a line ending follows `contentRange`. Only the last line
        /// has none.
        let hasLineEnding: Bool
    }

    let characters: [Character]

    /// Local offset of the first character of each line. Never empty.
    private let lineStarts: [Int]
    private let origin: SourceLocation

    /// Builds the text and its line table, charging one unit of work per
    /// character scanned.
    init(
        _ text: String,
        startingAt origin: SourceLocation = SourceLocation(line: 1, column: 1, offset: 0),
        budget: ParsingBudget
    ) {
        let characters = Array(text)
        var lineStarts = [0]
        for (offset, character) in characters.enumerated() where Self.isLineEnding(character) {
            lineStarts.append(offset + 1)
        }
        budget.consumeWork(characters.count)

        self.init(characters: characters, lineStarts: lineStarts, origin: origin)
    }

    private init(characters: [Character], lineStarts: [Int], origin: SourceLocation) {
        self.characters = characters
        self.lineStarts = lineStarts
        self.origin = origin
    }

    /// Whether `character` ends a line: LF, CR, or CRLF.
    static func isLineEnding(_ character: Character) -> Bool {
        character == "\n" || character == "\r" || character == "\r\n"
    }

    /// The position reached after walking over `text` from `start`.
    static func position(
        after text: some Sequence<Character>,
        from start: SourceLocation
    ) -> (line: Int, column: Int, offset: Int) {
        var line = start.line
        var column = start.column
        var offset = start.offset

        for character in text {
            offset += 1
            if isLineEnding(character) {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return (line, column, offset)
    }

    var count: Int {
        characters.count
    }

    var lines: [Line] {
        lineStarts.indices.map { index in
            let start = lineStarts[index]
            let hasLineEnding = index + 1 < lineStarts.count
            let end = hasLineEnding ? lineStarts[index + 1] - 1 : characters.count
            return Line(number: origin.line + index, contentRange: start..<end, hasLineEnding: hasLineEnding)
        }
    }

    /// The empty range at local `offset`, in the coordinate space of the
    /// text's origin. `offset` may equal `count`.
    func location(at offset: Int) -> SourceLocation {
        precondition(offset >= 0 && offset <= characters.count, "Offset outside the source text")

        let lineIndex = lineIndex(containing: offset)
        let column = lineIndex == 0
            ? origin.column + offset
            : offset - lineStarts[lineIndex] + 1
        return SourceLocation(
            line: origin.line + lineIndex,
            column: column,
            offset: origin.offset + offset
        )
    }

    /// The source range covering the local `offsets`.
    func range(_ offsets: Range<Int>) -> SourceLocation {
        let start = location(at: offsets.lowerBound)
        let end = location(at: offsets.upperBound)
        return start.spanning(to: end)
    }

    func string(in offsets: Range<Int>) -> String {
        String(characters[offsets])
    }

    /// Returns a text with every character in `ranges` replaced by a space,
    /// except tabs, which are kept. The line table, and therefore every
    /// location, is unchanged; ranges must not contain line endings.
    func blankingCharacters(in ranges: [Range<Int>]) -> MarkdownSourceText {
        guard !ranges.isEmpty else { return self }

        var blanked = characters
        for range in ranges {
            for offset in range {
                precondition(!Self.isLineEnding(blanked[offset]), "Cannot blank a line ending")
                if blanked[offset] != "\t" {
                    blanked[offset] = " "
                }
            }
        }
        return MarkdownSourceText(characters: blanked, lineStarts: lineStarts, origin: origin)
    }

    /// Index of the last line starting at or before `offset`.
    private func lineIndex(containing offset: Int) -> Int {
        var lower = 0
        var upper = lineStarts.count
        while upper - lower > 1 {
            let middle = (lower + upper) / 2
            if lineStarts[middle] <= offset {
                lower = middle
            } else {
                upper = middle
            }
        }
        return lower
    }
}
