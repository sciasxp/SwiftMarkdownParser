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

            // Check for setext heading
            if let setextHeading = try parseSetextHeading() {
                return setextHeading
            }

            // Default to paragraph
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

        // Use the inline parser to properly handle the heading content
        let inlineParser = makeInlineParser()
        let children = try inlineParser.parseInlines(until: [.newline, .eof])

        return AST.HeadingNode(
            level: level,
            children: children,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    private func parseSetextHeading() throws -> AST.HeadingNode? {
        // Look ahead to see if next line is setext underline
        let startPosition = tokenStream.currentPosition

        // Parse potential heading text
        var textTokens: [Token] = []
        while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
            textTokens.append(tokenStream.consume())
        }

        // Must have newline
        guard tokenStream.match(.newline) else {
            // Backtrack
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Check for underline

        guard !tokenStream.isAtEnd else {
            tokenStream.setPosition(startPosition)
            return nil
        }

        let underlineToken = tokenStream.current

        // A valid setext underline must be at least 3 consecutive '=' or '-' characters
        // and must not include other characters.
        let trimmedContent = underlineToken.content.trimmingCharacters(in: .whitespaces)
        let isLevel1 = trimmedContent.allSatisfy { $0 == "=" } && trimmedContent.count >= 3
        let isLevel2 = trimmedContent.allSatisfy { $0 == "-" } && trimmedContent.count >= 3

        guard isLevel1 || isLevel2 else {
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Consume underline token and any trailing newline
        tokenStream.advance()

        // Create heading
        let textContent = textTokens.map { $0.content }.joined()
        let inlineStart = textTokens.first?.location ?? underlineToken.location
        let children = try makeInlineParser().parseInlineContent(
            textContent.trimmingCharacters(in: .whitespacesAndNewlines),
            startingAt: inlineStart
        )

        return AST.HeadingNode(
            level: isLevel1 ? 1 : 2,
            children: children,
            sourceLocation: tokenStream.range(startingAt: inlineStart)
        )
    }

    // MARK: - Block Quote Parser

    private func parseBlockQuote() throws -> AST.BlockQuoteNode {
        let startLocation = tokenStream.current.location
        var children: [any ASTNode] = []

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
        tokenStream.advance()
        skipWhitespace()

        var children: [any ASTNode] = []

        // Parse inline content for the first line
        let taskMarker = tokenStream.check(.taskListMarker) ? tokenStream.consume() : nil
        if taskMarker != nil {
            skipWhitespace()
        }

        let inlineParser = makeInlineParser()
        let inlineNodes = try inlineParser.parseInlines(until: [.newline, .eof])

        // Create paragraph for first line if not empty
        if !inlineNodes.isEmpty {
            children.append(AST.ParagraphNode(
                children: inlineNodes,
                sourceLocation: tokenStream.range(startingAt: startLocation)
            ))
        }

        // Skip the newline if present
        _ = tokenStream.match(.newline)

        // Check if there's continuation content (indented blocks)
        while !tokenStream.isAtEnd {
            // Check if next line starts a new list item
            if isAtStartOfListItem() {
                break
            }

            // Check for blank line followed by non-indented content (ends list)
            if isBlankLineThenNonIndented() {
                break
            }

            // Special check: if we encounter a list marker at the start of a line
            // without proper indentation, it should end this list item
            if isListMarkerAtStartOfLine() {
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

    private func isBlankLineThenNonIndented() -> Bool {
        let currentPos = tokenStream.currentPosition

        // Check for blank line
        if !tokenStream.check(.newline) {
            return false
        }

        tokenStream.advance()

        // Skip any additional blank lines
        while tokenStream.check(.newline) {
            tokenStream.advance()
        }

        // Check if next content is non-indented
        var spaceCount = 0
        while tokenStream.check(.whitespace) && spaceCount < 4 {
            spaceCount += tokenStream.current.content.count
            tokenStream.advance()
        }

        let result = spaceCount < 4 && !tokenStream.isAtEnd

        // Restore position
        tokenStream.setPosition(currentPos)

        return result
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

        // Collect code content
        var content = ""

        while !tokenStream.isAtEnd {
            // Check for closing fence
            if tokenStream.check(.backtick) || tokenStream.check(.tildeCodeFence) {
                let closingToken = tokenStream.current
                if closingToken.content.first == fenceChar && closingToken.content.count >= fenceLength {
                    tokenStream.advance()
                    break
                }
            }

            if tokenStream.check(.newline) {
                content += "\n"
            } else {
                content += tokenStream.current.content
            }
            tokenStream.advance()
        }

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

    private func parseParagraph() throws -> AST.ParagraphNode {
        let startLocation = tokenStream.current.location

        // Use inline parser to properly handle inline elements like code spans, emphasis, etc.
        let inlineParser = makeInlineParser()
        let inlineNodes = try inlineParser.parseInlines(until: [.newline, .eof])

        return AST.ParagraphNode(
            children: inlineNodes,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
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
