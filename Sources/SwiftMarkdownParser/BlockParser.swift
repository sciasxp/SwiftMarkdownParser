/// Block parser for converting tokens into block-level AST nodes
///
/// This parser handles container blocks (block quotes, lists) and leaf blocks
/// (headings, paragraphs, code blocks) according to the CommonMark specification.
import Foundation

// MARK: - Block Parser

/// Parser for block-level markdown elements
final class BlockParser {

    private let tokenStream: TokenStream
    private let limits: SwiftMarkdownParser.ResourceLimits
    private let budget: ParsingBudget
    private let sourceText: MarkdownSourceText
    private let linkReferences: [String: LinkReference]
    private var nestingDepth = 0

    /// A container block open around the block being parsed.
    private enum Container {
        case blockQuote
        /// A list item whose content starts at `contentColumn` (1-based) on
        /// the line of its marker.
        case listItem(contentColumn: Int)
    }

    /// Containers open around the block being parsed, outermost first.
    private var containers: [Container] = []

    /// Offset of the first character of each line of `sourceText`.
    private let lineStarts: [Int]

    /// Where the block being parsed started, before its indentation.
    private var blockIndentationStart = 0

    init(
        tokenStream: TokenStream,
        limits: SwiftMarkdownParser.ResourceLimits,
        budget: ParsingBudget,
        sourceText: MarkdownSourceText,
        linkReferences: [String: LinkReference]
    ) {
        self.tokenStream = tokenStream
        self.limits = limits
        self.budget = budget
        self.sourceText = sourceText
        self.linkReferences = linkReferences
        self.lineStarts = sourceText.lines.map(\.contentRange.lowerBound)
    }

    /// Parse the entire document into an AST
    func parseDocument() throws -> AST.DocumentNode {
        var children: [any ASTNode] = []

        while !tokenStream.isAtEnd {
            let startingPosition = tokenStream.currentPosition

            if let block = try parseBlock() {
                children.append(block)
            }

            guard tokenStream.currentPosition > startingPosition || tokenStream.isAtEnd else {
                throw MarkdownParsingError.internalInvariant(
                    message: "Block parser made no progress at token \(startingPosition).",
                    location: tokenStream.current.location
                )
            }
        }

        let documentRange = sourceText.range(0..<sourceText.count)
        return AST.DocumentNode(children: children, sourceLocation: documentRange)
    }

    /// Parse a single block element
    private func parseBlock() throws -> (any ASTNode)? {
        // Skip whitespace at start of line
        blockIndentationStart = tokenStream.currentLocation.offset
        skipWhitespace()

        guard !tokenStream.isAtEnd else {
            return nil
        }

        let token = tokenStream.current

        switch token.type {
        case .atxHeaderStart:
            return try parseATXHeading()

        case .blockQuoteMarker:
            return try parseBlockQuote()

        case .listMarker:
            // A thematic break takes precedence over a list item
            if let thematicBreak = parseThematicBreakLine() {
                return thematicBreak
            }
            return try parseList()

        case .backtick, .tildeCodeFence:
            if token.content.count >= 3 {
                return try parseFencedCodeBlock()
            }
            // Single backticks should be treated as part of a paragraph, not as code blocks
            return try parseParagraph()

        case .dollarSign:
            if token.content == "$$" {
                return try parseMathBlock()
            }
            return try parseParagraph()

        case .indentedCodeBlock:
            return try parseIndentedCodeBlock()

        case .thematicBreak:
            return parseThematicBreak()

        case .htmlTag:
            return try parseHTMLBlock()

        case .newline:
            // Empty line - skip
            tokenStream.advance()
            return nil

        default:
            // Check for GFM table
            if let table = try parseSimpleGFMTable() {
                return table
            }

            // Default to paragraph; a setext underline turns it into a heading
            return try parseParagraph()
        }
    }

    // MARK: - Heading Parsers

    private func parseATXHeading() throws -> AST.HeadingNode {
        let startLocation = tokenStream.current.location
        let headerToken = tokenStream.consume()
        let level = headerToken.content.count

        // Skip whitespace after #
        skipWhitespace()

        // The rest of the line, without final spaces, is one inline fragment
        let contentStart = tokenStream.currentLocation
        let lineEnd = lineContentRange(lineIndex(containing: startLocation.offset)).upperBound
        let contentEnd = endTrimmingSpaces(lineEnd, notBefore: contentStart.offset)
        while !tokenStream.isAtEnd && tokenStream.currentLocation.offset < lineEnd {
            tokenStream.advance()
        }
        let children = contentStart.offset < contentEnd
            ? try makeInlineParser().parseInlineContent(
                sourceText.string(in: contentStart.offset..<contentEnd),
                startingAt: contentStart
            )
            : []

        return AST.HeadingNode(
            level: level,
            children: children,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    // MARK: - Block Quote Parser

    private func parseBlockQuote() throws -> AST.BlockQuoteNode {
        let startLocation = tokenStream.current.location
        var children: [any ASTNode] = []
        containers.append(.blockQuote)
        defer { containers.removeLast() }

        while !tokenStream.isAtEnd && tokenStream.check(.blockQuoteMarker) {
            tokenStream.advance() // consume >
            skipWhitespace()

            // Parse the content of this line
            if let block = try parseNestedBlock() {
                children.append(block)
            }

            // Look for continuation
            skipWhitespaceAndNewlines()
        }

        return AST.BlockQuoteNode(
            children: children,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    // MARK: - List Parsers

    private func parseList() throws -> AST.ListNode {
        let startLocation = tokenStream.current.location
        let firstMarker = tokenStream.current.content

        let isOrdered = firstMarker.last == "." || firstMarker.last == ")"
        let startNumber = isOrdered ? Int(firstMarker.dropLast()) : nil
        let delimiter = isOrdered ? firstMarker.last : nil
        let bulletChar = isOrdered ? nil : firstMarker.first

        var items: [any ASTNode] = []

        while !tokenStream.isAtEnd && tokenStream.check(.listMarker) {
            let marker = tokenStream.current.content

            // Check if this marker matches the list type
            let markerIsOrdered = marker.last == "." || marker.last == ")"
            if markerIsOrdered != isOrdered {
                break
            }

            if isOrdered {
                if marker.last != delimiter {
                    break
                }
            } else {
                if marker.first != bulletChar {
                    break
                }
            }

            // Parse list item
            let item = try parseListItem()
            items.append(item)

            skipWhitespaceAndNewlines()
        }

        return AST.ListNode(
            isOrdered: isOrdered,
            startNumber: startNumber,
            items: items,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    private func parseListItem() throws -> any ASTNode {
        let startLocation = tokenStream.current.location

        // Consume list marker
        let marker = tokenStream.consume()
        skipWhitespace()

        containers.append(.listItem(contentColumn: listItemContentColumn(after: marker)))
        defer { containers.removeLast() }

        var children: [any ASTNode] = []

        let taskMarker = tokenStream.check(.taskListMarker) ? tokenStream.consume() : nil
        if taskMarker != nil {
            skipWhitespace()
        }

        // The rest of the marker line starts the item's first block
        if !tokenStream.isAtEnd && !tokenStream.check(.newline), let block = try parseNestedBlock() {
            children.append(block)
        }

        // Check if there's continuation content (indented blocks)
        while !tokenStream.isAtEnd {
            // Check if next line starts a new list item
            if isAtStartOfListItem() {
                break
            }

            // Special check: if we encounter a list marker at the start of a line
            // without proper indentation, it should end this list item
            if isListMarkerAtStartOfLine() {
                break
            }

            // The item continues only on a line indented to its content
            guard advanceToNextLineOfItem(isEmpty: children.isEmpty) else {
                break
            }

            // Parse any continuation blocks
            if let block = try parseNestedBlock() {
                children.append(block)
            } else {
                break
            }
        }

        let itemRange = tokenStream.range(startingAt: startLocation)
        if let taskMarker {
            let marker = taskMarker.content.lowercased()
            let isChecked = marker != "[ ]"
            var taskChildren = children
            if let paragraph = children.first as? AST.ParagraphNode {
                taskChildren = paragraph.children + children.dropFirst()
            }
            return AST.GFMTaskListItemNode(
                isChecked: isChecked,
                children: taskChildren,
                sourceLocation: itemRange
            )
        }
        return AST.ListItemNode(children: children, sourceLocation: itemRange)
    }

    private func isAtStartOfListItem() -> Bool {
        // Check if we're at the start of a line with a list marker
        let currentPos = tokenStream.currentPosition

        // Skip to start of content (skip newlines first, then whitespace)
        while tokenStream.check(.newline) {
            tokenStream.advance()
        }

        // Track indentation level
        var indentLevel = 0
        while tokenStream.check(.whitespace) && indentLevel < 4 {
            indentLevel += 1
            tokenStream.advance()
        }

        let result = tokenStream.check(.listMarker)

        // Restore position
        tokenStream.setPosition(currentPos)

        return result
    }

    private func isListMarkerAtStartOfLine() -> Bool {
        let currentPos = tokenStream.currentPosition

        // Skip newlines to get to next line
        while tokenStream.check(.newline) {
            tokenStream.advance()
        }

        // Check for minimal indentation (0-3 spaces is acceptable for a new list)
        var spaceCount = 0
        while tokenStream.check(.whitespace) && spaceCount < 4 {
            spaceCount += 1
            tokenStream.advance()
        }

        // Check if there's a list marker here
        let hasListMarker = tokenStream.check(.listMarker)

        // Restore position
        tokenStream.setPosition(currentPos)

        return hasListMarker
    }

    /// The column where the content of the list item opened by `marker`
    /// starts; the token stream is at the first token after the marker's
    /// spaces.
    private func listItemContentColumn(after marker: Token) -> Int {
        let lineStart = lineStarts[lineIndex(containing: marker.location.offset)]
        let markerEnd = marker.location.offset + marker.content.count
        let contentStart = tokenStream.currentLocation.offset
        let isBlankItem = tokenStream.isAtEnd || tokenStream.check(.newline)
        // An empty item, or one whose content is indented code, keeps one space
        guard !isBlankItem, contentStart - markerEnd <= 4 else {
            return markerEnd - lineStart + 2
        }
        return contentStart - lineStart + 1
    }

    /// Moves to the content of the next non-blank line when that line belongs
    /// to the innermost list item; returns false when the item ends there.
    /// An empty item ends at a blank line: an item can begin with at most one
    /// blank line.
    private func advanceToNextLineOfItem(isEmpty: Bool) -> Bool {
        guard tokenStream.check(.newline) else { return true }

        var line = lineIndex(containing: tokenStream.currentLocation.offset) + 1
        if isEmpty && line < lineStarts.count && isBlank(lineContentRange(line)) {
            return false
        }
        while line < lineStarts.count && isBlank(lineContentRange(line)) {
            line += 1
        }
        guard line < lineStarts.count else { return false }

        let match = matchContainers(onLine: line)
        guard match.matched == containers.count else { return false }

        let keepsIndentedCode = leadingIndentation(at: match.restStart, line: line) >= 4
        while !tokenStream.isAtEnd && tokenStream.currentLocation.offset < match.restStart {
            if keepsIndentedCode && tokenStream.check(.indentedCodeBlock) {
                break
            }
            tokenStream.advance()
        }
        return true
    }

    // MARK: - Code Block Parsers

    private func parseFencedCodeBlock() throws -> any ASTNode {
        let startLocation = tokenStream.current.location
        let fenceToken = tokenStream.consume()
        let fenceChar = fenceToken.content.first!
        let fenceLength = fenceToken.content.count

        // Parse language info
        var language: String?
        var infoString = ""

        while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
            infoString += tokenStream.consume().content
        }

        if !infoString.isEmpty {
            language = infoString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first
        }

        // Skip newline after opening fence
        _ = tokenStream.match(.newline)

        // Find the closing fence; the tokenizer decides which fence closes
        var closingOffset: Int?
        while !tokenStream.isAtEnd {
            if tokenStream.check(.backtick) || tokenStream.check(.tildeCodeFence) {
                let closingToken = tokenStream.current
                if closingToken.content.first == fenceChar && closingToken.content.count >= fenceLength {
                    closingOffset = closingToken.location.offset
                    tokenStream.advance()
                    break
                }
            }
            tokenStream.advance()
        }

        let content = fencedCodeContent(
            openingFenceOffset: startLocation.offset,
            fenceIndentation: startLocation.offset - blockIndentationStart,
            closingFenceOffset: closingOffset
        )

        // Check if this is a Mermaid diagram
        if let language = language, language.lowercased() == "mermaid" {
            return AST.MermaidDiagramNode(
                content: content,
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        }

        // Regular code block
        return AST.CodeBlockNode(
            content: content,
            language: language,
            isFenced: true,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    /// The content lines between a fence and its closing fence (or the end of
    /// the text), without the prefixes of the open containers and without up
    /// to the opening fence's own indentation.
    private func fencedCodeContent(
        openingFenceOffset: Int,
        fenceIndentation: Int,
        closingFenceOffset: Int?
    ) -> String {
        let openingLine = lineIndex(containing: openingFenceOffset)
        let endLine = closingFenceOffset.map(lineIndex(containing:)) ?? lineStarts.count
        guard openingLine + 1 < endLine else { return "" }

        let characters = sourceText.characters
        var content = ""
        for line in (openingLine + 1)..<endLine {
            let lineRange = lineContentRange(line)
            let match = matchContainers(onLine: line)
            var start = match.matched == containers.count ? match.restStart : lineRange.lowerBound
            var removed = 0
            while removed < fenceIndentation && start < lineRange.upperBound && characters[start] == " " {
                start += 1
                removed += 1
            }
            content += sourceText.string(in: start..<lineRange.upperBound)
            if line + 1 < lineStarts.count {
                content += "\n"
            }
        }
        return content
    }

    private func parseMathBlock() throws -> any ASTNode {
        let startPosition = tokenStream.currentPosition
        let startLocation = tokenStream.current.location

        // Consume opening $$
        tokenStream.advance()

        // Skip newline after opening $$
        _ = tokenStream.match(.newline)

        // Collect content
        var content = ""
        var foundClosing = false

        while !tokenStream.isAtEnd {
            // Check for closing $$
            if tokenStream.check(.dollarSign) && tokenStream.current.content == "$$" {
                tokenStream.advance()
                foundClosing = true
                break
            }

            if tokenStream.check(.newline) {
                content += "\n"
            } else {
                content += tokenStream.current.content
            }
            tokenStream.advance()
        }

        // Strip trailing newline from content
        if content.hasSuffix("\n") {
            content = String(content.dropLast())
        }

        guard foundClosing else {
            tokenStream.setPosition(startPosition)
            return try parseParagraph()
        }

        return AST.MathBlockNode(
            content: content,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    private func parseIndentedCodeBlock() throws -> AST.CodeBlockNode {
        let startLocation = tokenStream.current.location
        var content = ""

        while !tokenStream.isAtEnd && tokenStream.check(.indentedCodeBlock) {
            _ = tokenStream.consume()

            // Collect rest of line
            var lineContent = ""
            while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
                lineContent += tokenStream.consume().content
            }

            content += lineContent

            if tokenStream.match(.newline) {
                content += "\n"
            }
        }

        return AST.CodeBlockNode(
            content: content,
            language: nil,
            isFenced: false,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    // MARK: - Other Block Parsers

    /// A thematic break whose marks the tokenizer read as list markers, such
    /// as `* * *` or `- - -`.
    private func parseThematicBreakLine() -> AST.ThematicBreakNode? {
        let startLocation = tokenStream.current.location
        let lineEnd = lineContentRange(lineIndex(containing: startLocation.offset)).upperBound
        let text = Substring(sourceText.string(in: startLocation.offset..<lineEnd))
        guard Self.isThematicBreak(text), let character = text.first else { return nil }

        while !tokenStream.isAtEnd && tokenStream.currentLocation.offset < lineEnd {
            tokenStream.advance()
        }
        return AST.ThematicBreakNode(
            character: character,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    private func parseThematicBreak() -> AST.ThematicBreakNode {
        let startLocation = tokenStream.current.location
        let token = tokenStream.consume()
        let character = token.content.first { !$0.isWhitespace } ?? "-"

        return AST.ThematicBreakNode(
            character: character,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }


    private func parseHTMLBlock() throws -> AST.HTMLBlockNode {
        let startLocation = tokenStream.current.location
        var content = ""

        // Simple HTML block parsing - collect until blank line
        while !tokenStream.isAtEnd {
            let token = tokenStream.consume()
            content += token.content

            if token.type == .newline {
                // Check if next line is blank
                if tokenStream.check(.newline) {
                    break
                }
                // The block ends with the container holding it
                let nextLine = lineIndex(containing: tokenStream.currentLocation.offset)
                if !tokenStream.isAtEnd && matchContainers(onLine: nextLine).matched < containers.count {
                    break
                }
            }
        }

        return AST.HTMLBlockNode(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    // MARK: - GFM Table Parser

    private func parseSimpleGFMTable() throws -> AST.GFMTableNode? {
        // Save current position for backtracking
        let startPosition = tokenStream.currentPosition

        // Simple approach: collect a few lines and check if they form a table
        var lines: [TableLine] = []

        // Collect table-shaped lines. Deterministic work accounting replaces
        // an arbitrary row-count limit.
        while !tokenStream.isAtEnd {
            let lineStartPosition = tokenStream.currentPosition
            if let line = collectCurrentLine() {
                if line.content.isEmpty || !GFMUtils.isTableRow(line.content) {
                    tokenStream.setPosition(lineStartPosition)
                    break
                }
                lines.append(line)

                if tokenStream.check(.newline) {
                    tokenStream.advance()
                }
            } else {
                break
            }
        }

        // Need at least 2 lines for a table (header + separator)
        guard lines.count >= 2 else {
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Check if first line is table row and second is separator
        guard GFMUtils.isTableRow(lines[0].content),
              GFMUtils.isTableHeaderSeparator(lines[1].content) else {
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Parse the table
        let alignments = GFMUtils.parseTableHeaderSeparator(lines[1].content)

        var rows: [AST.GFMTableRowNode] = []

        // Create header row
        let headerRow = AST.GFMTableRowNode(
            cells: try parseTableCells(
                in: lines[0],
                isHeader: true,
                alignments: alignments
            ),
            isHeader: true,
            sourceLocation: lines[0].range
        )
        rows.append(headerRow)

        // Create body rows (skip separator line at index 1)
        for i in 2..<lines.count {
            if GFMUtils.isTableRow(lines[i].content) {
                let cells = try parseTableCells(
                    in: lines[i],
                    isHeader: false,
                    alignments: alignments
                )
                let row = AST.GFMTableRowNode(
                    cells: cells,
                    isHeader: false,
                    sourceLocation: lines[i].range
                )
                rows.append(row)
            }
        }

        return AST.GFMTableNode(
            rows: rows,
            alignments: alignments,
            sourceLocation: lines[0].range.spanning(to: lines[lines.count - 1].range)
        )
    }

    /// One collected table line: its text and its document range, which
    /// ends where the line's newline or EOF token starts.
    private struct TableLine {
        let content: String
        let range: SourceLocation
    }

    private func parseTableCells(
        in line: TableLine,
        isHeader: Bool,
        alignments: [GFMTableAlignment]
    ) throws -> [AST.GFMTableCellNode] {
        let cellContents = GFMUtils.parseTableRow(line.content)
        var searchStart = line.content.startIndex
        var cells: [AST.GFMTableCellNode] = []

        for (index, cellContent) in cellContents.enumerated() {
            let trimmed = cellContent.trimmingCharacters(in: .whitespaces)
            let contentRange = line.content.range(of: trimmed, range: searchStart..<line.content.endIndex)
            let startDelta = contentRange.map {
                line.content.distance(from: line.content.startIndex, to: $0.lowerBound)
            } ?? 0
            let cellOffset = line.range.offset + startDelta
            assert(cellOffset + trimmed.count <= line.range.endOffset, "Table cell extends past its line")
            let cellRange = sourceText.range(cellOffset..<cellOffset + trimmed.count)
            let cellStart = SourceLocation(line: cellRange.line, column: cellRange.column, offset: cellRange.offset)
            let children: [any ASTNode]
            if trimmed.isEmpty {
                children = []
            } else if needsInlineParsing(trimmed) {
                children = try makeInlineParser().parseInlineContent(trimmed, startingAt: cellStart)
            } else {
                children = [AST.TextNode(content: trimmed, sourceLocation: cellRange)]
            }
            let alignment = index < alignments.count ? alignments[index] : .none

            cells.append(AST.GFMTableCellNode(
                children: children,
                isHeader: isHeader,
                alignment: alignment,
                sourceLocation: cellRange
            ))
            if let contentRange {
                searchStart = contentRange.upperBound
            }
        }
        return cells
    }

    private func needsInlineParsing(_ source: String) -> Bool {
        source.contains { "*_`[!~$\\&<".contains($0) } ||
            source.contains("http://") ||
            source.contains("https://") ||
            source.contains("www.") ||
            source.contains("@")
    }

    private func collectCurrentLine() -> TableLine? {
        guard !tokenStream.isAtEnd && !tokenStream.check(.newline) else {
            return nil
        }

        let startLocation = tokenStream.current.location
        var lineContent = ""

        // Collect all tokens until newline
        while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
            lineContent += tokenStream.consume().content
        }

        let endOffset = tokenStream.currentLocation.offset
        return TableLine(content: lineContent, range: sourceText.range(startLocation.offset..<endOffset))
    }

    /// Parses a paragraph: its first line plus every continuation line, lazy
    /// or not. A setext underline after the lines makes it a heading.
    private func parseParagraph() throws -> any ASTNode {
        let startLocation = tokenStream.current.location
        let start = startLocation.offset
        var line = lineIndex(containing: start)
        var end = lineContentRange(line).upperBound
        var consumedEnd = end
        var continuationPrefixes: [Range<Int>] = []
        var setextLevel: Int?

        while line + 1 < lineStarts.count {
            let next = line + 1
            let match = matchContainers(onLine: next)
            let rest = match.restStart..<lineContentRange(next).upperBound
            guard !isBlank(rest) else { break }

            let isLazy = match.matched < containers.count
            if !isLazy, let level = setextUnderlineLevel(rest) {
                setextLevel = level
                consumedEnd = rest.upperBound
                break
            }
            let closesListItem = containers[match.matched...].contains {
                if case .listItem = $0 { return true }
                return false
            }
            guard !interruptsParagraph(rest, line: next, closesListItem: closesListItem) else { break }

            continuationPrefixes.append(lineStarts[next]..<firstNonWhitespace(in: rest))
            end = rest.upperBound
            consumedEnd = end
            line = next
        }

        // Final spaces and tabs are not content
        end = endTrimmingSpaces(end, notBefore: start)

        while !tokenStream.isAtEnd && tokenStream.currentLocation.offset < consumedEnd {
            tokenStream.advance()
        }

        // Container prefixes and indentation of continuation lines become
        // spaces, so the fragment keeps the source's offsets and columns.
        var fragment = Array(sourceText.characters[start..<end])
        for prefix in continuationPrefixes {
            for offset in prefix where !MarkdownSourceText.isLineEnding(fragment[offset - start]) {
                fragment[offset - start] = " "
            }
        }
        let children = fragment.isEmpty
            ? []
            : try makeInlineParser().parseInlineContent(String(fragment), startingAt: startLocation)

        let range = tokenStream.range(startingAt: startLocation)
        if let setextLevel {
            return AST.HeadingNode(level: setextLevel, children: children, sourceLocation: range)
        }
        return AST.ParagraphNode(children: children, sourceLocation: range)
    }

    // MARK: - Lines

    /// Index of the line containing `offset`.
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

    /// The characters of `line`, excluding its line ending.
    private func lineContentRange(_ line: Int) -> Range<Int> {
        let end = line + 1 < lineStarts.count ? lineStarts[line + 1] - 1 : sourceText.count
        return lineStarts[line]..<end
    }

    /// Matches the open containers against the start of `line`, outermost
    /// first: a block quote needs its `>`, a list item needs indentation to
    /// its content column or a blank line. Returns where the rest of the line
    /// starts and how many containers matched.
    private func matchContainers(onLine line: Int) -> (restStart: Int, matched: Int) {
        let characters = sourceText.characters
        let lineRange = lineContentRange(line)
        var position = lineRange.lowerBound
        var matched = 0

        for container in containers {
            switch container {
            case .blockQuote:
                var cursor = position
                while cursor < lineRange.upperBound && characters[cursor] == " " && cursor - position < 3 {
                    cursor += 1
                }
                guard cursor < lineRange.upperBound && characters[cursor] == ">" else {
                    return (position, matched)
                }
                cursor += 1
                if cursor < lineRange.upperBound && (characters[cursor] == " " || characters[cursor] == "\t") {
                    cursor += 1
                }
                position = cursor
            case .listItem(let contentColumn):
                let target = lineRange.lowerBound + contentColumn - 1
                if isBlank(position..<lineRange.upperBound) || target <= position {
                    break
                }
                guard target <= lineRange.upperBound,
                      (position..<target).allSatisfy({ characters[$0] == " " || characters[$0] == "\t" }) else {
                    return (position, matched)
                }
                position = target
            }
            matched += 1
        }
        return (position, matched)
    }

    private func isBlank(_ range: Range<Int>) -> Bool {
        let characters = sourceText.characters
        return range.allSatisfy { characters[$0] == " " || characters[$0] == "\t" }
    }

    /// `end` moved back over the spaces and tabs before it, not past `start`.
    private func endTrimmingSpaces(_ end: Int, notBefore start: Int) -> Int {
        let characters = sourceText.characters
        var end = end
        while end > start && (characters[end - 1] == " " || characters[end - 1] == "\t") {
            end -= 1
        }
        return end
    }

    private func firstNonWhitespace(in range: Range<Int>) -> Int {
        let characters = sourceText.characters
        return range.first { characters[$0] != " " && characters[$0] != "\t" } ?? range.upperBound
    }

    /// Columns of indentation at `offset`, with tabs to the next multiple of 4.
    private func leadingIndentation(at offset: Int, line: Int) -> Int {
        let characters = sourceText.characters
        let lineRange = lineContentRange(line)
        var indentation = 0
        var cursor = offset
        while cursor < lineRange.upperBound {
            if characters[cursor] == " " {
                indentation += 1
            } else if characters[cursor] == "\t" {
                indentation += 4 - indentation % 4
            } else {
                break
            }
            cursor += 1
        }
        return indentation
    }

    /// The level of a setext underline (`=` for 1, `-` for 2) filling `range`.
    private func setextUnderlineLevel(_ range: Range<Int>) -> Int? {
        let text = sourceText.string(in: range)
        let indentation = text.prefix { $0 == " " }.count
        guard indentation < 4 else { return nil }
        let underline = text.dropFirst(indentation).trimmingCharacters(in: .whitespaces)
        guard let character = underline.first, character == "=" || character == "-",
              underline.allSatisfy({ $0 == character }) else {
            return nil
        }
        return character == "=" ? 1 : 2
    }

    /// Whether the rest of `line`, at `range`, starts a block that ends the
    /// paragraph before it. When the line closes a list item, any list item
    /// start interrupts; otherwise only a non-empty bullet item or an ordered
    /// item starting at 1 does.
    private func interruptsParagraph(_ range: Range<Int>, line: Int, closesListItem: Bool) -> Bool {
        guard leadingIndentation(at: range.lowerBound, line: line) < 4 else { return false }
        let text = Substring(sourceText.string(in: firstNonWhitespace(in: range)..<range.upperBound))
        guard let first = text.first else { return false }

        switch first {
        case ">":
            return true
        case "#":
            let hashes = text.prefix { $0 == "#" }
            let after = text.dropFirst(hashes.count).first
            return hashes.count <= 6 && (after == nil || after == " " || after == "\t")
        case "`", "~":
            let fence = text.prefix { $0 == first }
            return fence.count >= 3 && (first == "~" || !text.dropFirst(fence.count).contains("`"))
        case "$":
            return text.hasPrefix("$$")
        case "<":
            return Self.startsHTMLBlock(text)
        default:
            break
        }

        if Self.isThematicBreak(text) {
            return true
        }
        if let item = Self.listItemStart(text) {
            return closesListItem || (item.hasContent && (item.number == nil || item.number == 1))
        }
        if line + 1 < lineStarts.count, GFMUtils.isTableRow(String(text)) {
            let match = matchContainers(onLine: line + 1)
            let separator = sourceText.string(in: match.restStart..<lineContentRange(line + 1).upperBound)
            return match.matched == containers.count && GFMUtils.isTableHeaderSeparator(separator)
        }
        return false
    }

    private static func isThematicBreak(_ text: Substring) -> Bool {
        let marks = text.filter { $0 != " " && $0 != "\t" }
        guard let mark = marks.first, "-*_".contains(mark) else { return false }
        return marks.count >= 3 && marks.allSatisfy { $0 == mark }
    }

    /// A list item marker at the start of `text`: the ordered number, if any,
    /// and whether content follows the marker.
    private static func listItemStart(_ text: Substring) -> (number: Int?, hasContent: Bool)? {
        var rest = text
        var number: Int?
        if let first = text.first, "-+*".contains(first) {
            rest = text.dropFirst()
        } else {
            let digits = text.prefix { $0.isASCII && $0.isNumber }
            guard (1...9).contains(digits.count),
                  let delimiter = text.dropFirst(digits.count).first, delimiter == "." || delimiter == ")" else {
                return nil
            }
            number = Int(digits)
            rest = text.dropFirst(digits.count + 1)
        }
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        return (number, rest.contains { $0 != " " && $0 != "\t" })
    }

    /// Block-level HTML tag names that start an HTML block (CommonMark 0.30, type 6).
    private static let htmlBlockTagNames: Set<String> = [
        "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption", "center",
        "col", "colgroup", "dd", "details", "dialog", "dir", "div", "dl", "dt", "fieldset",
        "figcaption", "figure", "footer", "form", "frame", "frameset", "h1", "h2", "h3", "h4", "h5",
        "h6", "head", "header", "hr", "html", "iframe", "legend", "li", "link", "main", "menu",
        "menuitem", "nav", "noframes", "ol", "optgroup", "option", "p", "param", "section", "source",
        "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track", "ul",
    ]

    /// Whether `text` starts an HTML block that can interrupt a paragraph
    /// (CommonMark 0.30 types 1 to 6).
    private static func startsHTMLBlock(_ text: Substring) -> Bool {
        let lowercased = text.lowercased()
        for name in ["script", "pre", "style", "textarea"] where lowercased.hasPrefix("<" + name) {
            let after = lowercased.dropFirst(name.count + 1).first
            if after == nil || after == ">" || after?.isWhitespace == true {
                return true
            }
        }
        if text.hasPrefix("<!--") || text.hasPrefix("<?") || text.hasPrefix("<![CDATA[") {
            return true
        }
        if text.hasPrefix("<!"), let letter = text.dropFirst(2).first, letter.isASCII, letter.isLetter {
            return true
        }

        var name = lowercased.dropFirst()
        if name.hasPrefix("/") {
            name = name.dropFirst()
        }
        let tag = name.prefix { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard htmlBlockTagNames.contains(String(tag)) else { return false }
        let after = name.dropFirst(tag.count)
        return after.isEmpty || after.first?.isWhitespace == true || after.hasPrefix(">") || after.hasPrefix("/>")
    }

    // MARK: - Utility Methods

    private func skipWhitespace() {
        while tokenStream.check(.whitespace) {
            tokenStream.advance()
        }
    }

    private func skipWhitespaceAndNewlines() {
        while tokenStream.check(.whitespace) || tokenStream.check(.newline) {
            tokenStream.advance()
        }
    }

    private func makeInlineParser() -> InlineParser {
        InlineParser(
            tokenStream: tokenStream,
            budget: budget,
            linkReferences: linkReferences,
            maximumNestingDepth: limits.maximumNestingDepth
        )
    }

    private func parseNestedBlock() throws -> (any ASTNode)? {
        nestingDepth += 1
        defer { nestingDepth -= 1 }

        guard nestingDepth <= limits.maximumNestingDepth else {
            throw MarkdownParsingError.resourceLimitExceeded(
                resource: .nestingDepth,
                limit: limits.maximumNestingDepth,
                actual: nestingDepth
            )
        }
        return try parseBlock()
    }
}
